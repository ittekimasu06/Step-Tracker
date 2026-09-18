package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.HourlyStepEntryRequest;
import com.steptrack.dto.HourlyStepEntryResponse;
import com.steptrack.dto.HourlyStepsListResponse;
import com.steptrack.dto.HourlyStepsUpdateRequest;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.service.StepService;
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
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the /steps/{date}/hours endpoints through the real servlet container, same approach
 * as {@link StepsFlowIntegrationTest}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class HourlyStepsFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    @Autowired
    private StepService stepService;

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

    private static HourlyStepsUpdateRequest oneHour(int hour, int steps, int activeMinutes) {
        return HourlyStepsUpdateRequest.builder()
                .hours(List.of(HourlyStepEntryRequest.builder()
                        .hourOfDay(hour).stepCount(steps).activeMinutes(activeMinutes).build()))
                .build();
    }

    @Test
    void hourlyStepsRequireAuthentication() {
        String today = LocalDate.now().toString();

        ResponseEntity<String> anonGet = rest.getForEntity("/steps/" + today + "/hours", String.class);
        assertThat(anonGet.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> anonPut = rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(8, 100, 5)), String.class);
        assertThat(anonPut.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void malformedDateIsRejected() {
        String token = registerAndGetToken();

        ResponseEntity<String> response = rest.exchange(
                "/steps/not-a-date/hours", HttpMethod.GET, bearer(token), String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void getHourlyStepsForUnknownDateReturnsEmptyListNotNotFound() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();

        ResponseEntity<HourlyStepsListResponse> response = rest.exchange(
                "/steps/" + today + "/hours", HttpMethod.GET, bearer(token), HourlyStepsListResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody().getHours()).isEmpty();
    }

    @Test
    void hourCanBeUpsertedAndReadBack() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<HourlyStepsListResponse> put = rest.exchange("/steps/" + today + "/hours",
                HttpMethod.PUT, new HttpEntity<>(oneHour(9, 420, 4), headers), HourlyStepsListResponse.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(put.getBody().getHours()).hasSize(1);
        assertThat(put.getBody().getHours().get(0).getHourOfDay()).isEqualTo(9);
        assertThat(put.getBody().getHours().get(0).getStepCount()).isEqualTo(420);
        assertThat(put.getBody().getHours().get(0).getActiveMinutes()).isEqualTo(4);

        ResponseEntity<HourlyStepsListResponse> get = rest.exchange(
                "/steps/" + today + "/hours", HttpMethod.GET, bearer(token), HourlyStepsListResponse.class);
        assertThat(get.getBody().getHours()).hasSize(1);
        assertThat(get.getBody().getHours().get(0).getStepCount()).isEqualTo(420);
    }

    @Test
    void puttingSameHourTwiceOverwritesRatherThanAccumulates() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(14, 100, 1), headers), HourlyStepsListResponse.class);
        ResponseEntity<HourlyStepsListResponse> second = rest.exchange("/steps/" + today + "/hours",
                HttpMethod.PUT, new HttpEntity<>(oneHour(14, 250, 3), headers), HourlyStepsListResponse.class);

        assertThat(second.getBody().getHours()).hasSize(1);
        assertThat(second.getBody().getHours().get(0).getStepCount()).isEqualTo(250);
        assertThat(second.getBody().getHours().get(0).getActiveMinutes()).isEqualTo(3);
    }

    @Test
    void batchPutWithMultipleHoursPersistsAll() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        HourlyStepsUpdateRequest batch = HourlyStepsUpdateRequest.builder()
                .hours(List.of(
                        HourlyStepEntryRequest.builder().hourOfDay(7).stepCount(50).activeMinutes(0).build(),
                        HourlyStepEntryRequest.builder().hourOfDay(8).stepCount(300).activeMinutes(6).build(),
                        HourlyStepEntryRequest.builder().hourOfDay(9).stepCount(120).activeMinutes(1).build()))
                .build();

        rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(batch, headers), HourlyStepsListResponse.class);

        ResponseEntity<HourlyStepsListResponse> get = rest.exchange(
                "/steps/" + today + "/hours", HttpMethod.GET, bearer(token), HourlyStepsListResponse.class);
        List<HourlyStepEntryResponse> hours = get.getBody().getHours();
        assertThat(hours).hasSize(3);
        assertThat(hours).extracting(HourlyStepEntryResponse::getHourOfDay)
                .containsExactly(7, 8, 9);
    }

    @Test
    void invalidHourOfDayIsRejected() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<String> tooHigh = rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(24, 10, 0), headers), String.class);
        assertThat(tooHigh.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        ResponseEntity<String> negative = rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(-1, 10, 0), headers), String.class);
        assertThat(negative.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void oneUsersTokenNeverExposesAnotherUsersHourlySteps() {
        String tokenA = registerAndGetToken();
        String tokenB = registerAndGetToken();
        String today = LocalDate.now().toString();

        HttpHeaders headersA = new HttpHeaders();
        headersA.setBearerAuth(tokenA);
        rest.exchange("/steps/" + today + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(10, 999, 9), headersA), HourlyStepsListResponse.class);

        ResponseEntity<HourlyStepsListResponse> hoursB = rest.exchange(
                "/steps/" + today + "/hours", HttpMethod.GET, bearer(tokenB), HourlyStepsListResponse.class);

        assertThat(hoursB.getBody().getHours()).isEmpty();
    }

    @Test
    void deletingAccountRemovesHourlyStepHistoryWithoutError() {
        String token = registerAndGetToken();
        String today = LocalDate.now().toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        ResponseEntity<HourlyStepsListResponse> put = rest.exchange("/steps/" + today + "/hours",
                HttpMethod.PUT, new HttpEntity<>(oneHour(11, 200, 2), headers), HourlyStepsListResponse.class);
        assertThat(put.getStatusCode()).isEqualTo(HttpStatus.OK);

        ResponseEntity<Void> deleted = rest.exchange(
                "/profile", HttpMethod.DELETE, bearer(token), Void.class);

        assertThat(deleted.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
    }

    @Test
    void purgeOldHourlyDataRemovesOnlyDataOlderThanRetentionWindow() {
        String token = registerAndGetToken();
        String oldDate = LocalDate.now().minusDays(10).toString();
        String recentDate = LocalDate.now().minusDays(2).toString();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);

        rest.exchange("/steps/" + oldDate + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(6, 100, 1), headers), HourlyStepsListResponse.class);
        rest.exchange("/steps/" + recentDate + "/hours", HttpMethod.PUT,
                new HttpEntity<>(oneHour(6, 100, 1), headers), HourlyStepsListResponse.class);

        stepService.purgeOldHourlyData();

        ResponseEntity<HourlyStepsListResponse> oldAfter = rest.exchange(
                "/steps/" + oldDate + "/hours", HttpMethod.GET, bearer(token), HourlyStepsListResponse.class);
        ResponseEntity<HourlyStepsListResponse> recentAfter = rest.exchange(
                "/steps/" + recentDate + "/hours", HttpMethod.GET, bearer(token), HourlyStepsListResponse.class);

        assertThat(oldAfter.getBody().getHours()).isEmpty();
        assertThat(recentAfter.getBody().getHours()).hasSize(1);
    }
}
