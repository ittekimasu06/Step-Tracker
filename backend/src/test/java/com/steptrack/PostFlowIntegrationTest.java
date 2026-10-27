package com.steptrack;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.dto.StepEntryRequest;
import com.steptrack.dto.UserProfileRequest;
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
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Drives the /posts endpoints through the real servlet container, same approach as {@link
 * FriendshipFlowIntegrationTest}. Focuses on the feed's friends-only visibility boundary and
 * on {@code PostService.like}/{@code unlike} independently re-checking that boundary rather
 * than trusting the feed already filtered things correctly.
 */
@SuppressWarnings("unchecked")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class PostFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private static String uniqueUsername() {
        return "user" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
    }

    private String registerWithName(String fullName) {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> response = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).username(uniqueUsername())
                        .password("secret123").passwordConfirm("secret123").build(),
                AuthResponse.class);
        String token = response.getBody().getToken();

        HttpHeaders headers = authHeaders(token);
        rest.exchange("/profile", HttpMethod.PUT,
                new HttpEntity<>(UserProfileRequest.builder().fullName(fullName).build(), headers),
                Map.class);
        return token;
    }

    private HttpHeaders authHeaders(String token) {
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(token);
        return headers;
    }

    private UUID userIdFromProfile(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/profile", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return UUID.fromString((String) response.getBody().get("id"));
    }

    /** Sends a request from {@code aToken} to {@code bToken} and accepts it as B. */
    private void befriend(String aToken, String bToken) {
        UUID bId = userIdFromProfile(bToken);
        rest.exchange("/friends/requests", HttpMethod.POST,
                new HttpEntity<>(Map.of("targetUserId", bId.toString()), authHeaders(aToken)), Void.class);
        UUID requestId = UUID.fromString((String) incomingRequests(bToken).get(0).get("id"));
        rest.exchange("/friends/requests/" + requestId + "/accept", HttpMethod.POST,
                new HttpEntity<>(authHeaders(bToken)), Void.class);
    }

    private List<Map<String, Object>> incomingRequests(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends/requests", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("requests");
    }

    private void setTodaySteps(String token, int steps, int activeMinutes) {
        String today = LocalDate.now().toString();
        rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(
                        StepEntryRequest.builder().stepCount(steps).activeMinutes(activeMinutes).build(),
                        authHeaders(token)),
                Void.class);
    }

    private Map<String, Object> createPost(String token, int calorieCount) {
        ResponseEntity<Map> response = rest.exchange(
                "/posts", HttpMethod.POST,
                new HttpEntity<>(Map.of("calorieCount", calorieCount), authHeaders(token)), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        return response.getBody();
    }

    private List<Map<String, Object>> feed(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/posts/feed", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("posts");
    }

    @Test
    void createdPostCapturesTodaysStepsAndSubmittedCalories() {
        String token = registerWithName("Sharer Person");
        setTodaySteps(token, 2145, 23);

        Map<String, Object> post = createPost(token, 73);

        assertThat(post.get("stepCount")).isEqualTo(2145);
        assertThat(post.get("activeMinutes")).isEqualTo(23);
        assertThat(post.get("calorieCount")).isEqualTo(73);
        assertThat(post.get("likeCount")).isEqualTo(0);
        assertThat(post.get("likedByMe")).isEqualTo(false);
    }

    @Test
    void feedShowsFriendsAndOwnPostsButNotAStranger() {
        String aToken = registerWithName("Feed A");
        String bToken = registerWithName("Feed B");
        String strangerToken = registerWithName("Feed Stranger");
        befriend(aToken, bToken);

        setTodaySteps(aToken, 1000, 10);
        setTodaySteps(bToken, 2000, 20);
        createPost(aToken, 50);
        createPost(bToken, 60);

        List<Map<String, Object>> aFeed = feed(aToken);
        assertThat(aFeed).hasSize(2);

        List<Map<String, Object>> strangerFeed = feed(strangerToken);
        assertThat(strangerFeed).isEmpty();
    }

    @Test
    void likingAFriendsPostIncrementsCountAndLikedByMe() {
        String aToken = registerWithName("Like A");
        String bToken = registerWithName("Like B");
        befriend(aToken, bToken);

        Map<String, Object> post = createPost(bToken, 10);
        UUID postId = UUID.fromString((String) post.get("id"));

        ResponseEntity<Void> liked = rest.exchange("/posts/" + postId + "/like", HttpMethod.POST,
                new HttpEntity<>(authHeaders(aToken)), Void.class);
        assertThat(liked.getStatusCode()).isEqualTo(HttpStatus.OK);

        List<Map<String, Object>> aFeed = feed(aToken);
        Map<String, Object> seen = aFeed.stream()
                .filter(p -> p.get("id").equals(postId.toString()))
                .findFirst().orElseThrow();
        assertThat(seen.get("likeCount")).isEqualTo(1);
        assertThat(seen.get("likedByMe")).isEqualTo(true);

        ResponseEntity<Void> unliked = rest.exchange("/posts/" + postId + "/like", HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(aToken)), Void.class);
        assertThat(unliked.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);
        Map<String, Object> afterUnlike = feed(aToken).stream()
                .filter(p -> p.get("id").equals(postId.toString()))
                .findFirst().orElseThrow();
        assertThat(afterUnlike.get("likeCount")).isEqualTo(0);
    }

    @Test
    void likingANonFriendsPostIsRejected() {
        String authorToken = registerWithName("Private Author");
        String strangerToken = registerWithName("Nosy Liker");

        Map<String, Object> post = createPost(authorToken, 10);
        UUID postId = UUID.fromString((String) post.get("id"));

        ResponseEntity<Map> response = rest.exchange("/posts/" + postId + "/like", HttpMethod.POST,
                new HttpEntity<>(authHeaders(strangerToken)), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void endpointsRequireAuthentication() {
        ResponseEntity<String> response = rest.getForEntity("/posts/feed", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }
}
