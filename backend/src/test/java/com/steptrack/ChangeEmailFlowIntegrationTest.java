package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.service.StubEmailService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the /profile/email/change, /profile/email/confirm and /profile/email/resend
 * endpoints through the real servlet container, same approach as {@link
 * EmailVerificationFlowIntegrationTest}/{@link FriendshipFlowIntegrationTest}. These three
 * live on {@code ProfileController} (not {@code AuthController}) because {@code /auth/**} is
 * {@code permitAll()} in {@code SecurityConfig} - every request here must carry a bearer
 * token.
 */
@SuppressWarnings("unchecked")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class ChangeEmailFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private static String uniqueUsername() {
        return "user" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }

    private HttpHeaders authHeaders(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return headers;
    }

    /** Registers, verifies, and returns a usable token - same password for every account. */
    private String registerAndVerify(String email) {
        rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        String code = StubEmailService.lastCodeFor(email);
        ResponseEntity<AuthResponse> verified = rest.postForEntity("/auth/verify-email",
                Map.of("email", email, "code", code), AuthResponse.class);
        return verified.getBody().getToken();
    }

    private ResponseEntity<Map> requestChange(String token, String currentPassword, String newEmail) {
        return rest.exchange("/profile/email/change", HttpMethod.POST,
                new HttpEntity<>(Map.of("currentPassword", currentPassword, "newEmail", newEmail), authHeaders(token)),
                Map.class);
    }

    private ResponseEntity<AuthResponse> confirmChange(String token, String code) {
        return rest.exchange("/profile/email/confirm", HttpMethod.POST,
                new HttpEntity<>(Map.of("code", code), authHeaders(token)), AuthResponse.class);
    }

    private ResponseEntity<Map> resendChangeCode(String token) {
        return rest.exchange("/profile/email/resend", HttpMethod.POST,
                new HttpEntity<>(authHeaders(token)), Map.class);
    }

    private ResponseEntity<Map> getProfile(String token) {
        return rest.exchange("/profile", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
    }

    @Test
    void requestWithWrongPasswordIsRejected() {
        String token = registerAndVerify(uniqueEmail());

        ResponseEntity<Map> response = requestChange(token, "wrong-password", uniqueEmail());

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void requestWithEmailAlreadyTakenByAnotherAccountIsRejected() {
        String otherEmail = uniqueEmail();
        registerAndVerify(otherEmail);
        String token = registerAndVerify(uniqueEmail());

        ResponseEntity<Map> response = requestChange(token, "secret123", otherEmail);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void fullFlowIssuesNewTokenAndInvalidatesTheOldOne() {
        String oldEmail = uniqueEmail();
        String newEmail = uniqueEmail();
        String oldToken = registerAndVerify(oldEmail);

        ResponseEntity<Map> requestResponse = requestChange(oldToken, "secret123", newEmail);
        assertThat(requestResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        String code = StubEmailService.lastCodeFor(newEmail);
        assertThat(code).isNotNull();

        ResponseEntity<AuthResponse> wrongCode = confirmChange(oldToken, "000000");
        assertThat(wrongCode.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<AuthResponse> confirmResponse = confirmChange(oldToken, code);
        assertThat(confirmResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        String newToken = confirmResponse.getBody().getToken();
        assertThat(newToken).isNotBlank();

        // The old token's subject (oldEmail) no longer resolves to any account.
        ResponseEntity<Map> staleTokenResponse = getProfile(oldToken);
        assertThat(staleTokenResponse.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<Map> freshTokenResponse = getProfile(newToken);
        assertThat(freshTokenResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(freshTokenResponse.getBody().get("email")).isEqualTo(newEmail);

        assertThat(StubEmailService.lastChangeNoticeFor(oldEmail)).isEqualTo(newEmail);
    }

    @Test
    void resendIsThrottledOnImmediateRetry() {
        String token = registerAndVerify(uniqueEmail());
        requestChange(token, "secret123", uniqueEmail());

        ResponseEntity<Map> firstResend = resendChangeCode(token);
        assertThat(firstResend.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Map> secondResend = resendChangeCode(token);
        assertThat(secondResend.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
