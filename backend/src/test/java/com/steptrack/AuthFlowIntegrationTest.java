package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.LoginRequest;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.dto.UserProfileRequest;
import com.steptrack.dto.UserProfileResponse;
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

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the API through the real servlet container so the configured
 * {@code server.servlet.context-path=/api} is exercised end to end - which is exactly
 * where the security path matchers previously went wrong.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class AuthFlowIntegrationTest {

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

    @Test
    void healthEndpointIsPublic() {
        ResponseEntity<String> response = rest.getForEntity("/health", String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).contains("UP");
    }

    @Test
    void registerReturnsTokenAndIsPublic() {
        String email = uniqueEmail();
        RegisterRequest request = RegisterRequest.builder()
                .email(email)
                .username(uniqueUsername())
                .password("secret123")
                .passwordConfirm("secret123")
                .build();

        ResponseEntity<AuthResponse> response =
                rest.postForEntity("/auth/register", request, AuthResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().getToken()).isNotBlank();
        assertThat(response.getBody().getEmail()).isEqualTo(email);
    }

    @Test
    void registerRejectsMismatchedPasswordConfirmation() {
        RegisterRequest request = RegisterRequest.builder()
                .email(uniqueEmail())
                .username(uniqueUsername())
                .password("secret123")
                .passwordConfirm("something-else")
                .build();

        ResponseEntity<AuthResponse> response =
                rest.postForEntity("/auth/register", request, AuthResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void registerRejectsDuplicateEmail() {
        String email = uniqueEmail();
        RegisterRequest request = RegisterRequest.builder()
                .email(email)
                .username(uniqueUsername())
                .password("secret123")
                .passwordConfirm("secret123")
                .build();

        rest.postForEntity("/auth/register", request, AuthResponse.class);
        ResponseEntity<AuthResponse> duplicate =
                rest.postForEntity("/auth/register", request, AuthResponse.class);

        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void loginSucceedsWithCorrectPasswordAndFailsWithWrongOne() {
        String email = uniqueEmail();
        rest.postForEntity("/auth/register", RegisterRequest.builder()
                .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);

        ResponseEntity<AuthResponse> ok = rest.postForEntity("/auth/login",
                LoginRequest.builder().email(email).password("secret123").build(),
                AuthResponse.class);
        assertThat(ok.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(ok.getBody()).isNotNull();
        assertThat(ok.getBody().getToken()).isNotBlank();

        ResponseEntity<AuthResponse> denied = rest.postForEntity("/auth/login",
                LoginRequest.builder().email(email).password("wrong-password").build(),
                AuthResponse.class);
        assertThat(denied.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void profileRequiresAuthentication() {
        ResponseEntity<String> anonymous = rest.getForEntity("/profile", String.class);
        assertThat(anonymous.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        ResponseEntity<String> badToken = rest.exchange(
                "/profile", HttpMethod.GET, bearer("not-a-real-token"), String.class);
        assertThat(badToken.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void profileCanBeUpdatedAndReadBackWithToken() {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> registered = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        String token = registered.getBody().getToken();

        // A freshly registered user has a profile that is not yet completed.
        ResponseEntity<UserProfileResponse> initial = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), UserProfileResponse.class);
        assertThat(initial.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(initial.getBody().getProfileCompleted()).isFalse();
        assertThat(initial.getBody().getEmail()).isEqualTo(email);

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        UserProfileRequest update = UserProfileRequest.builder()
                .fullName("Ada Lovelace")
                .age(36)
                .weightKg(new BigDecimal("62.50"))
                .heightCm(new BigDecimal("168.00"))
                .gender("female")
                .profileCompleted(true)
                .stepGoal(8000)
                .activeMinutesGoal(60)
                .calorieGoal(650)
                .build();

        ResponseEntity<UserProfileResponse> updated = rest.exchange(
                "/profile", HttpMethod.PUT, new HttpEntity<>(update, headers),
                UserProfileResponse.class);
        assertThat(updated.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(updated.getBody().getFullName()).isEqualTo("Ada Lovelace");
        assertThat(updated.getBody().getProfileCompleted()).isTrue();

        // The update must survive a round trip to the database.
        ResponseEntity<UserProfileResponse> reread = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), UserProfileResponse.class);
        assertThat(reread.getBody().getFullName()).isEqualTo("Ada Lovelace");
        assertThat(reread.getBody().getAge()).isEqualTo(36);
        assertThat(reread.getBody().getWeightKg()).isEqualByComparingTo("62.50");
        assertThat(reread.getBody().getHeightCm()).isEqualByComparingTo("168.00");
        assertThat(reread.getBody().getGender()).isEqualTo("female");
        assertThat(reread.getBody().getProfileCompleted()).isTrue();
        assertThat(reread.getBody().getStepGoal()).isEqualTo(8000);
        assertThat(reread.getBody().getActiveMinutesGoal()).isEqualTo(60);
        assertThat(reread.getBody().getCalorieGoal()).isEqualTo(650);
    }

    @Test
    void unsetGoalsDefaultToNullNotZero() {
        String email = uniqueEmail();
        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        ResponseEntity<UserProfileResponse> response = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), UserProfileResponse.class);

        assertThat(response.getBody().getStepGoal()).isNull();
        assertThat(response.getBody().getActiveMinutesGoal()).isNull();
        assertThat(response.getBody().getCalorieGoal()).isNull();
    }

    @Test
    void goalsCanBeUpdatedIndependentlyOfProfileFields() {
        String email = uniqueEmail();
        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder().fullName("Grace Hopper").build(), headers),
                UserProfileResponse.class);

        ResponseEntity<UserProfileResponse> goalsOnly = rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder().stepGoal(9000).build(), headers),
                UserProfileResponse.class);

        assertThat(goalsOnly.getBody().getStepGoal()).isEqualTo(9000);
        assertThat(goalsOnly.getBody().getFullName()).isEqualTo("Grace Hopper");
    }

    @Test
    void oneUsersTokenNeverExposesAnotherUsersProfile() {
        String emailA = uniqueEmail();
        String tokenA = rest.postForEntity("/auth/register", RegisterRequest.builder()
                .email(emailA).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        String emailB = uniqueEmail();
        String tokenB = rest.postForEntity("/auth/register", RegisterRequest.builder()
                .email(emailB).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(tokenA);
        rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder().fullName("User A").build(), headers),
                UserProfileResponse.class);

        ResponseEntity<UserProfileResponse> profileB = rest.exchange(
                "/profile", HttpMethod.GET, bearer(tokenB), UserProfileResponse.class);

        assertThat(profileB.getBody().getEmail()).isEqualTo(emailB);
        assertThat(profileB.getBody().getFullName()).isNull();
    }

    @Test
    void deletedAccountCanNoLongerAuthenticateEvenWithItsOldToken() {
        String email = uniqueEmail();
        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        ResponseEntity<Void> deleted = rest.exchange(
                "/profile", HttpMethod.DELETE, bearer(token), Void.class);
        assertThat(deleted.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        // The JWT is still well-formed and unexpired, but the account behind it is gone.
        ResponseEntity<String> afterDelete = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), String.class);
        assertThat(afterDelete.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

        // The email is free to register again.
        ResponseEntity<AuthResponse> reRegistered = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername()).password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        assertThat(reRegistered.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }

    @Test
    void registerRequiresUsername() {
        RegisterRequest request = RegisterRequest.builder()
                .email(uniqueEmail())
                .password("secret123")
                .passwordConfirm("secret123")
                .build();

        ResponseEntity<AuthResponse> response =
                rest.postForEntity("/auth/register", request, AuthResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void registerRejectsDuplicateUsernameCaseInsensitively() {
        String username = uniqueUsername();
        rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(uniqueEmail()).username(username)
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);

        ResponseEntity<AuthResponse> duplicate = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(uniqueEmail()).username(username.toUpperCase())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);

        assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void registeredUsernameIsReturnedOnProfile() {
        String username = uniqueUsername();
        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(uniqueEmail()).username(username)
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        ResponseEntity<UserProfileResponse> profile = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), UserProfileResponse.class);
        assertThat(profile.getBody().getUsername()).isEqualTo(username);
    }

    @Test
    void changingUsernameToOneAlreadyTakenIsRejected() {
        String takenUsername = uniqueUsername();
        rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(uniqueEmail()).username(takenUsername)
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);

        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(uniqueEmail()).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        ResponseEntity<String> response = rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder().username(takenUsername).build(), headers),
                String.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(response.getBody()).contains("Username already taken");
    }

    @Test
    void descriptionAndAvatarIdRoundTripCorrectly() {
        String token = rest.postForEntity("/auth/register", RegisterRequest.builder()
                        .email(uniqueEmail()).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class).getBody().getToken();

        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder()
                        .description("Hi, I like walking!").avatarId("avatar_horse.png").build(), headers),
                UserProfileResponse.class);

        ResponseEntity<UserProfileResponse> reread = rest.exchange(
                "/profile", HttpMethod.GET, bearer(token), UserProfileResponse.class);
        assertThat(reread.getBody().getDescription()).isEqualTo("Hi, I like walking!");
        assertThat(reread.getBody().getAvatarId()).isEqualTo("avatar_horse.png");
    }
}
