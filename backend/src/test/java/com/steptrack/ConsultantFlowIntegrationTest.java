package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.service.StubConsultantAiClient;
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
 * Drives the /consultant/advice endpoint through the real servlet container, same approach
 * as {@link StepsFlowIntegrationTest}. Uses {@link StubConsultantAiClient} (active under the
 * "test" profile) instead of the real Anthropic API - see that class's Javadoc.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class ConsultantFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private String registerAndGetToken() {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> response = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        return response.getBody().getToken();
    }

    @Test
    void adviceRequiresAuthentication() {
        ResponseEntity<String> response = rest.postForEntity("/consultant/advice", null, String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void brandNewUserGetsAdviceNotAnError() {
        String token = registerAndGetToken();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<Map> response = rest.exchange(
                "/consultant/advice", HttpMethod.POST, new HttpEntity<>(headers), Map.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().get("advice")).isEqualTo(StubConsultantAiClient.CANNED_ADVICE);
    }

    @Test
    void secondRequestWithinCooldownIsRejected() {
        String token = registerAndGetToken();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<String> first = rest.exchange(
                "/consultant/advice", HttpMethod.POST, new HttpEntity<>(headers), String.class);
        assertThat(first.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<String> second = rest.exchange(
                "/consultant/advice", HttpMethod.POST, new HttpEntity<>(headers), String.class);
        assertThat(second.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(second.getBody()).contains("wait");
    }
}
