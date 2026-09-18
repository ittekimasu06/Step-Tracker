package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.dto.StepEntryRequest;
import com.steptrack.dto.StepEntryResponse;
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

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the /steps endpoints through the real servlet container, same approach as
 * {@link AuthFlowIntegrationTest}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class StepsFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private static String uniqueUsername() {
        return "user" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }

    private static HttpEntity<Void> bearer(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return new HttpEntity<>(headers);
    }

    private String registerAndGetToken() {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> response = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        return response.getBody().getToken();
    }

    @Test
    void stepsRequireAuthentication() {
        String today = LocalDate.now().toString();

        ResponseEntity<String> anonGet = rest.getForEntity("/steps/" + today, String.class);
        assertThat(anonGet.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> anonPut = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(100).activeMinutes(5).build()),
                String.class);
        assertThat(anonPut.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void getStepsForUnknownDateReturnsZeroNotFound() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();

        ResponseEntity<StepEntryResponse> response = rest.exchange(
                "/steps/" + today, HttpMethod.GET, bearer(token), StepEntryResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getStepCount()).isEqualTo(0);
        assertThat(response.getBody().getActiveMinutes()).isEqualTo(0);
    }

    @Test
    void stepsCanBeUpsertedAndReadBack() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<StepEntryResponse> put = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(4210).activeMinutes(42).build(), headers),
                StepEntryResponse.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(put.getBody().getStepCount()).isEqualTo(4210);
        assertThat(put.getBody().getActiveMinutes()).isEqualTo(42);

        ResponseEntity<StepEntryResponse> get = rest.exchange(
                "/steps/" + today, HttpMethod.GET, bearer(token), StepEntryResponse.class);
        assertThat(get.getBody().getStepCount()).isEqualTo(4210);
        assertThat(get.getBody().getActiveMinutes()).isEqualTo(42);
    }

    @Test
    void puttingSameDateTwiceOverwritesRatherThanAccumulates() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(100).activeMinutes(10).build(), headers),
                StepEntryResponse.class);
        ResponseEntity<StepEntryResponse> second = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(250).activeMinutes(25).build(), headers),
                StepEntryResponse.class);

        assertThat(second.getBody().getStepCount()).isEqualTo(250);
        assertThat(second.getBody().getActiveMinutes()).isEqualTo(25);
    }

    @Test
    void negativeStepCountIsRejected() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<String> response = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(-1).activeMinutes(0).build(), headers),
                String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void negativeActiveMinutesIsRejected() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<String> response = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(0).activeMinutes(-1).build(), headers),
                String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void malformedDateIsRejected() {
        String token = registerAndGetToken();

        ResponseEntity<String> response = rest.exchange(
                "/steps/not-a-date", HttpMethod.GET, bearer(token), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void oneUsersTokenNeverExposesAnotherUsersSteps() {
        String tokenA = registerAndGetToken();
        String tokenB = registerAndGetToken();
        String today = LocalDate.now().toString();

        HttpHeaders headersA = new HttpHeaders();
        headersA.setBearerAuth(tokenA);
        rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(9999).activeMinutes(99).build(), headersA),
                StepEntryResponse.class);

        ResponseEntity<StepEntryResponse> stepsB = rest.exchange(
                "/steps/" + today, HttpMethod.GET, bearer(tokenB), StepEntryResponse.class);

        assertThat(stepsB.getBody().getStepCount()).isEqualTo(0);
        assertThat(stepsB.getBody().getActiveMinutes()).isEqualTo(0);
    }

    @Test
    void deletingAccountRemovesStepHistoryWithoutError() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<StepEntryResponse> put = rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(500).activeMinutes(15).build(), headers),
                StepEntryResponse.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Void> deleted = rest.exchange(
                "/profile", HttpMethod.DELETE, bearer(token), Void.class);

        assertThat(deleted.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }
}
