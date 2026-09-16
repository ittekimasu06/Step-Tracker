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
 * Drives the /friends endpoints through the real servlet container, same approach as
 * {@link ConsultantFlowIntegrationTest}. This feature is the first cross-user data access
 * in the codebase, so the tests focus as much on the *boundary* (a stranger can never see
 * another user's data, an accept/decline can never touch someone else's request) as on the
 * happy path. List endpoints wrap their list in a named field (e.g. {@code {"friends": [...]}})
 * - see {@code FriendListResponse} etc. - matching this codebase's existing convention (see
 * {@code HourlyStepsListResponse}) rather than returning a bare JSON array.
 */
@SuppressWarnings("unchecked")
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class FriendshipFlowIntegrationTest {

    @Autowired
    private TestRestTemplate rest;

    private static String uniqueEmail() {
        return "user-" + UUID.randomUUID() + "@example.com";
    }

    private String registerWithName(String fullName) {
        String email = uniqueEmail();
        ResponseEntity<AuthResponse> response = rest.postForEntity("/auth/register",
                RegisterRequest.builder()
                        .email(email).password("secret123").passwordConfirm("secret123").build(),
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

    private List<Map<String, Object>> searchResults(String token, String query) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends/search?query=" + query, HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("results");
    }

    private List<Map<String, Object>> incomingRequests(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends/requests", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("requests");
    }

    private List<Map<String, Object>> friendsList(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("friends");
    }

    private void sendRequest(String fromToken, UUID targetUserId) {
        rest.exchange("/friends/requests", HttpMethod.POST,
                new HttpEntity<>(Map.of("targetUserId", targetUserId.toString()), authHeaders(fromToken)),
                Void.class);
    }

    private List<Map<String, Object>> sentRequests(String token) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends/requests/sent", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("requests");
    }

    private void setTodaySteps(String token, int steps) {
        String today = LocalDate.now().toString();
        rest.exchange("/steps/" + today, HttpMethod.PUT,
                new HttpEntity<>(StepEntryRequest.builder().stepCount(steps).activeMinutes(0).build(), authHeaders(token)),
                Void.class);
    }

    private List<Map<String, Object>> leaderboard(String token, String period) {
        ResponseEntity<Map> response = rest.exchange(
                "/friends/leaderboard?period=" + period, HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)), Map.class);
        return (List<Map<String, Object>>) response.getBody().get("entries");
    }

    @Test
    void searchFindsUserByFullName() {
        String aToken = registerWithName("Alice Example");
        registerWithName("Bob Distinctive Wanderwood");

        List<Map<String, Object>> results = searchResults(aToken, "Wanderwood");

        assertThat(results).hasSize(1);
        assertThat(results.get(0).get("fullName")).isEqualTo("Bob Distinctive Wanderwood");
        assertThat(results.get(0).get("status")).isEqualTo("NONE");
    }

    @Test
    void searchRejectsTooShortQuery() {
        String token = registerWithName("Someone");
        ResponseEntity<Map> response = rest.exchange(
                "/friends/search?query=ab", HttpMethod.GET, new HttpEntity<>(authHeaders(token)), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void fullRequestAcceptFlowExposesOnlyStepsAndActiveMinutes() {
        String aToken = registerWithName("Requester Person");
        String bToken = registerWithName("Addressee Person");
        UUID bId = userIdFromProfile(bToken);

        ResponseEntity<Void> sent = rest.exchange(
                "/friends/requests", HttpMethod.POST,
                new HttpEntity<>(Map.of("targetUserId", bId.toString()), authHeaders(aToken)), Void.class);
        assertThat(sent.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        List<Map<String, Object>> incoming = incomingRequests(bToken);
        assertThat(incoming).hasSize(1);
        assertThat(incoming.get(0).get("fromFullName")).isEqualTo("Requester Person");
        UUID requestId = UUID.fromString((String) incoming.get(0).get("id"));

        ResponseEntity<Void> accepted = rest.exchange(
                "/friends/requests/" + requestId + "/accept", HttpMethod.POST,
                new HttpEntity<>(authHeaders(bToken)), Void.class);
        assertThat(accepted.getStatusCode()).isEqualTo(HttpStatus.OK);

        List<Map<String, Object>> aFriends = friendsList(aToken);
        assertThat(aFriends).hasSize(1);
        Map<String, Object> friendRow = aFriends.get(0);
        assertThat(friendRow.get("fullName")).isEqualTo("Addressee Person");
        assertThat(friendRow).containsKeys("todaySteps", "todayActiveMinutes");
        assertThat(friendRow).doesNotContainKeys("weightKg", "heightCm", "age", "gender");
    }

    @Test
    void mutualRequestsAutoAcceptInsteadOfTwoPendingRows() {
        String aToken = registerWithName("Mutual A");
        String bToken = registerWithName("Mutual B");
        UUID aId = userIdFromProfile(aToken);
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        ResponseEntity<Void> reverse = rest.exchange("/friends/requests", HttpMethod.POST,
                new HttpEntity<>(Map.of("targetUserId", aId.toString()), authHeaders(bToken)), Void.class);
        assertThat(reverse.getStatusCode()).isEqualTo(HttpStatus.CREATED);

        assertThat(incomingRequests(bToken)).isEmpty();
        assertThat(friendsList(aToken)).hasSize(1);
    }

    @Test
    void acceptingSomeoneElsesRequestIsRejected() {
        String aToken = registerWithName("Victim Requester");
        String bToken = registerWithName("Real Addressee");
        String cToken = registerWithName("Nosy Third Party");
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        UUID requestId = UUID.fromString((String) incomingRequests(bToken).get(0).get("id"));

        ResponseEntity<Map> stolen = rest.exchange(
                "/friends/requests/" + requestId + "/accept", HttpMethod.POST,
                new HttpEntity<>(authHeaders(cToken)), Map.class);
        assertThat(stolen.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }

    @Test
    void nonFriendNeverAppearsInFriendsList() {
        String aToken = registerWithName("Alone A");
        registerWithName("Stranger B");

        assertThat(friendsList(aToken)).isEmpty();
    }

    @Test
    void unfriendRemovesVisibilityBothWays() {
        String aToken = registerWithName("Ex Friend A");
        String bToken = registerWithName("Ex Friend B");
        UUID aId = userIdFromProfile(aToken);
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        UUID requestId = UUID.fromString((String) incomingRequests(bToken).get(0).get("id"));
        rest.exchange("/friends/requests/" + requestId + "/accept", HttpMethod.POST,
                new HttpEntity<>(authHeaders(bToken)), Void.class);

        ResponseEntity<Void> removed = rest.exchange(
                "/friends/" + aId, HttpMethod.DELETE, new HttpEntity<>(authHeaders(bToken)), Void.class);
        assertThat(removed.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(friendsList(aToken)).isEmpty();
    }

    @Test
    void endpointsRequireAuthentication() {
        ResponseEntity<String> response = rest.getForEntity("/friends", String.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void sentRequestShowsUpForRequesterOnly() {
        String aToken = registerWithName("Sender Person");
        String bToken = registerWithName("Recipient Person");
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);

        List<Map<String, Object>> aSent = sentRequests(aToken);
        assertThat(aSent).hasSize(1);
        assertThat(aSent.get(0).get("toFullName")).isEqualTo("Recipient Person");

        assertThat(sentRequests(bToken)).isEmpty();
    }

    @Test
    void cancellingSomeoneElsesSentRequestIsRejected() {
        String aToken = registerWithName("Cancel Victim");
        String bToken = registerWithName("Cancel Target");
        String cToken = registerWithName("Cancel Nosy");
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        UUID requestId = UUID.fromString((String) sentRequests(aToken).get(0).get("id"));

        ResponseEntity<Map> stolen = rest.exchange(
                "/friends/requests/" + requestId, HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(cToken)), Map.class);
        assertThat(stolen.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

        // Confirm it's untouched - still visible to the real sender.
        assertThat(sentRequests(aToken)).hasSize(1);
    }

    @Test
    void cancellingOwnSentRequestRemovesIt() {
        String aToken = registerWithName("Own Canceller");
        String bToken = registerWithName("Own Cancel Target");
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        UUID requestId = UUID.fromString((String) sentRequests(aToken).get(0).get("id"));

        ResponseEntity<Void> cancelled = rest.exchange(
                "/friends/requests/" + requestId, HttpMethod.DELETE,
                new HttpEntity<>(authHeaders(aToken)), Void.class);
        assertThat(cancelled.getStatusCode()).isEqualTo(HttpStatus.NO_CONTENT);

        assertThat(sentRequests(aToken)).isEmpty();
        assertThat(incomingRequests(bToken)).isEmpty();
    }

    @Test
    void leaderboardIncludesSelfAndFriendsSortedByStepsForDayPeriod() {
        String aToken = registerWithName("Leader Board A");
        String bToken = registerWithName("Leader Board B");
        UUID aId = userIdFromProfile(aToken);
        UUID bId = userIdFromProfile(bToken);

        sendRequest(aToken, bId);
        UUID requestId = UUID.fromString((String) incomingRequests(bToken).get(0).get("id"));
        rest.exchange("/friends/requests/" + requestId + "/accept", HttpMethod.POST,
                new HttpEntity<>(authHeaders(bToken)), Void.class);

        setTodaySteps(aToken, 5000);
        // B never logs any steps today - must still appear, ranked at 0, not omitted.

        List<Map<String, Object>> board = leaderboard(aToken, "day");
        assertThat(board).hasSize(2);
        assertThat(board.get(0).get("userId")).isEqualTo(aId.toString());
        assertThat(board.get(0).get("steps")).isEqualTo(5000);
        assertThat(board.get(0).get("isSelf")).isEqualTo(true);
        assertThat(board.get(1).get("userId")).isEqualTo(bId.toString());
        assertThat(board.get(1).get("steps")).isEqualTo(0);
        assertThat(board.get(1).get("isSelf")).isEqualTo(false);
    }

    @Test
    void leaderboardRejectsInvalidPeriod() {
        String token = registerWithName("Bad Period Person");
        ResponseEntity<Map> response = rest.exchange(
                "/friends/leaderboard?period=year", HttpMethod.GET,
                new HttpEntity<>(authHeaders(token)), Map.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);
    }
}
