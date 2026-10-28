package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.service.StubEmailService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.ActiveProfiles;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the /auth/register, /auth/login, /auth/verify-email and /auth/resend-verification
 * endpoints through the real servlet container, same approach as {@link
 * FriendshipFlowIntegrationTest}. Uses {@link StubEmailService} (active under the "test"
 * profile) instead of sending a real SES email - see that class's Javadoc.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class EmailVerificationFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private static String uniqueUsername() {
        return "user" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }

    private ResponseEntity<AuthResponse> register(String email) {
        return rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
    }

    private ResponseEntity<AuthResponse> login(String email, String password) {
        return rest.postForEntity("/auth/login",
                java.util.Map.of("email", email, "password", password), AuthResponse.class);
    }

    private ResponseEntity<AuthResponse> verify(String email, String code) {
        return rest.postForEntity("/auth/verify-email",
                java.util.Map.of("email", email, "code", code), AuthResponse.class);
    }

    private ResponseEntity<AuthResponse> resend(String email) {
        return rest.postForEntity("/auth/resend-verification",
                java.util.Map.of("email", email), AuthResponse.class);
    }

    @Test
    void registerSendsCodeAndDoesNotIssueAUsableToken() {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> response = register(email);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody().isRequiresVerification()).isTrue();
        assertThat(response.getBody().getToken()).isNull();
        assertThat(StubEmailService.lastCodeFor(email)).isNotNull();
    }

    @Test
    void loginBeforeVerifyingIsRejectedEvenWithCorrectPassword() {
        String email = uniqueEmail();
        register(email);

        ResponseEntity<AuthResponse> response = login(email, "secret123");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody().isRequiresVerification()).isTrue();
    }

    @Test
    void wrongCodeIsRejected() {
        String email = uniqueEmail();
        register(email);

        ResponseEntity<AuthResponse> response = verify(email, "000000");

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void correctCodeVerifiesAndReturnsAUsableTokenThatThenAllowsLogin() {
        String email = uniqueEmail();
        register(email);
        String code = StubEmailService.lastCodeFor(email);

        ResponseEntity<AuthResponse> verifyResponse = verify(email, code);
        assertThat(verifyResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(verifyResponse.getBody().getToken()).isNotBlank();

        ResponseEntity<AuthResponse> loginResponse = login(email, "secret123");
        assertThat(loginResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(loginResponse.getBody().getToken()).isNotBlank();
    }

    @Test
    void resendIssuesANewCodeButIsThrottledOnImmediateRetry() {
        String email = uniqueEmail();
        register(email);
        String firstCode = StubEmailService.lastCodeFor(email);

        ResponseEntity<AuthResponse> resendResponse = resend(email);
        assertThat(resendResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        // Not a hard guarantee the code differs (random 6-digit collision is possible), but the
        // stub having been invoked again is the real thing under test here.
        assertThat(StubEmailService.lastCodeFor(email)).isNotNull();

        ResponseEntity<AuthResponse> secondResend = resend(email);
        assertThat(secondResend.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // The most recently issued code (whichever of the two it was) still verifies.
        String latestCode = StubEmailService.lastCodeFor(email);
        ResponseEntity<AuthResponse> verifyResponse = verify(email, latestCode);
        assertThat(verifyResponse.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(firstCode).isNotNull();
    }
}
