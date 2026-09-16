package com.steptrack.service;

import com.steptrack.dto.FriendListResponse;
import com.steptrack.dto.FriendRequestListResponse;
import com.steptrack.dto.FriendRequestResponse;
import com.steptrack.dto.FriendSummaryResponse;
import com.steptrack.dto.LeaderboardEntry;
import com.steptrack.dto.LeaderboardResponse;
import com.steptrack.dto.SentFriendRequestListResponse;
import com.steptrack.dto.SentFriendRequestResponse;
import com.steptrack.dto.UserSearchListResponse;
import com.steptrack.dto.UserSearchResult;
import com.steptrack.model.DailySteps;
import com.steptrack.model.Friendship;
import com.steptrack.model.Friendship.FriendshipStatus;
import com.steptrack.model.User;
import com.steptrack.model.UserProfile;
import com.steptrack.repository.DailyStepsRepository;
import com.steptrack.repository.FriendshipRepository;
import com.steptrack.repository.UserProfileRepository;
import com.steptrack.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * The first place in this codebase one authenticated user's request ever reads another
 * user's data. Every cross-user read/write is scoped structurally, inside the repository
 * query itself (see {@link FriendshipRepository}), rather than via a separate "is this
 * mine" guard clause that could be forgotten - a friend's UUID is only ever *derived*
 * from an ACCEPTED {@link Friendship} row naming the caller, never accepted as an
 * unchecked request parameter.
 */
@Service
@RequiredArgsConstructor
public class FriendshipService {

    private static final Logger logger = LoggerFactory.getLogger(FriendshipService.class);
    private static final int MIN_QUERY_LENGTH = 3;

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final DailyStepsRepository dailyStepsRepository;
    private final FriendshipRepository friendshipRepository;

    public UserSearchListResponse search(String email, String query) {
        UUID selfId = requireUser(email).getId();
        if (query == null || query.trim().length() < MIN_QUERY_LENGTH) {
            throw new IllegalArgumentException(
                    "Search query must be at least " + MIN_QUERY_LENGTH + " characters");
        }

        List<UserProfile> matches =
                userProfileRepository.findTop20ByFullNameContainingIgnoreCaseAndIdNot(query.trim(), selfId);

        List<UserSearchResult> results = matches.stream()
                .map(profile -> UserSearchResult.builder()
                        .userId(profile.getId())
                        .fullName(profile.getFullName())
                        .status(relationshipStatus(selfId, profile.getId()))
                        .build())
                .collect(Collectors.toList());
        return UserSearchListResponse.builder().results(results).build();
    }

    private String relationshipStatus(UUID selfId, UUID otherId) {
        Optional<Friendship> outgoing = friendshipRepository.findByRequesterIdAndAddresseeId(selfId, otherId);
        if (outgoing.isPresent()) {
            return outgoing.get().getStatus() == FriendshipStatus.ACCEPTED ? "FRIENDS" : "PENDING_SENT";
        }
        Optional<Friendship> incoming = friendshipRepository.findByRequesterIdAndAddresseeId(otherId, selfId);
        if (incoming.isPresent()) {
            return incoming.get().getStatus() == FriendshipStatus.ACCEPTED ? "FRIENDS" : "PENDING_RECEIVED";
        }
        return "NONE";
    }

    @Transactional
    public void sendRequest(String email, UUID targetUserId) {
        UUID selfId = requireUser(email).getId();
        if (selfId.equals(targetUserId)) {
            throw new IllegalArgumentException("Cannot send a friend request to yourself");
        }
        if (!userRepository.existsById(targetUserId)) {
            throw new IllegalArgumentException("User not found");
        }

        Optional<Friendship> reverse = friendshipRepository.findByRequesterIdAndAddresseeId(targetUserId, selfId);
        if (reverse.isPresent()) {
            Friendship existing = reverse.get();
            if (existing.getStatus() == FriendshipStatus.ACCEPTED) {
                throw new IllegalArgumentException("Already friends");
            }
            // The other person already requested us - a mutual request becomes an
            // instant friendship rather than sitting as two separate PENDING rows.
            existing.setStatus(FriendshipStatus.ACCEPTED);
            friendshipRepository.save(existing);
            logger.info("Mutual friend request auto-accepted between {} and {}", selfId, targetUserId);
            return;
        }

        Optional<Friendship> forward = friendshipRepository.findByRequesterIdAndAddresseeId(selfId, targetUserId);
        if (forward.isPresent()) {
            throw new IllegalArgumentException(
                    forward.get().getStatus() == FriendshipStatus.ACCEPTED
                            ? "Already friends"
                            : "Friend request already sent");
        }

        friendshipRepository.save(Friendship.builder()
                .requesterId(selfId)
                .addresseeId(targetUserId)
                .status(FriendshipStatus.PENDING)
                .build());
        logger.info("Friend request sent from {} to {}", selfId, targetUserId);
    }

    public FriendRequestListResponse getIncomingRequests(String email) {
        UUID selfId = requireUser(email).getId();
        List<Friendship> incoming = friendshipRepository.findByAddresseeIdAndStatus(selfId, FriendshipStatus.PENDING);

        List<FriendRequestResponse> requests = incoming.stream()
                .map(f -> FriendRequestResponse.builder()
                        .id(f.getId())
                        .fromUserId(f.getRequesterId())
                        .fromFullName(fullNameOf(f.getRequesterId()))
                        .createdAt(f.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
        return FriendRequestListResponse.builder().requests(requests).build();
    }

    public SentFriendRequestListResponse getSentRequests(String email) {
        UUID selfId = requireUser(email).getId();
        List<Friendship> outgoing = friendshipRepository.findByRequesterIdAndStatus(selfId, FriendshipStatus.PENDING);

        List<SentFriendRequestResponse> requests = outgoing.stream()
                .map(f -> SentFriendRequestResponse.builder()
                        .id(f.getId())
                        .toUserId(f.getAddresseeId())
                        .toFullName(fullNameOf(f.getAddresseeId()))
                        .createdAt(f.getCreatedAt())
                        .build())
                .collect(Collectors.toList());
        return SentFriendRequestListResponse.builder().requests(requests).build();
    }

    @Transactional
    public void cancelSentRequest(String email, UUID requestId) {
        UUID selfId = requireUser(email).getId();
        Friendship request = friendshipRepository
                .findByIdAndRequesterIdAndStatus(requestId, selfId, FriendshipStatus.PENDING)
                .orElseThrow(() -> new IllegalArgumentException("Friend request not found"));
        friendshipRepository.delete(request);
        logger.info("Friend request {} cancelled by {}", requestId, selfId);
    }

    private static final Set<String> VALID_LEADERBOARD_PERIODS = Set.of("day", "week", "month");

    public LeaderboardResponse getLeaderboard(String email, String period) {
        User self = requireUser(email);
        if (period == null || !VALID_LEADERBOARD_PERIODS.contains(period)) {
            throw new IllegalArgumentException("Invalid period - must be one of day, week, month");
        }

        LocalDate today = LocalDate.now();
        LocalDate from = switch (period) {
            case "week" -> today.minusDays(6);
            case "month" -> today.minusDays(29);
            default -> today;
        };

        List<Friendship> accepted = friendshipRepository.findByStatusInvolving(self.getId(), FriendshipStatus.ACCEPTED);
        List<UUID> participantIds = accepted.stream()
                .map(f -> f.getRequesterId().equals(self.getId()) ? f.getAddresseeId() : f.getRequesterId())
                .collect(Collectors.toList());
        participantIds.add(self.getId());

        List<LeaderboardEntry> entries = participantIds.stream()
                .map(userId -> LeaderboardEntry.builder()
                        .userId(userId)
                        .fullName(fullNameOf(userId))
                        .steps(dailyStepsRepository.sumStepsBetween(userId, from, today))
                        .isSelf(userId.equals(self.getId()))
                        .build())
                .sorted(Comparator.comparingInt(LeaderboardEntry::getSteps).reversed()
                        .thenComparing(LeaderboardEntry::getFullName))
                .collect(Collectors.toList());

        return LeaderboardResponse.builder().entries(entries).build();
    }

    @Transactional
    public void acceptRequest(String email, UUID requestId) {
        UUID selfId = requireUser(email).getId();
        Friendship request = friendshipRepository
                .findByIdAndAddresseeIdAndStatus(requestId, selfId, FriendshipStatus.PENDING)
                .orElseThrow(() -> new IllegalArgumentException("Friend request not found"));
        request.setStatus(FriendshipStatus.ACCEPTED);
        friendshipRepository.save(request);
        logger.info("Friend request {} accepted by {}", requestId, selfId);
    }

    @Transactional
    public void declineRequest(String email, UUID requestId) {
        UUID selfId = requireUser(email).getId();
        Friendship request = friendshipRepository
                .findByIdAndAddresseeIdAndStatus(requestId, selfId, FriendshipStatus.PENDING)
                .orElseThrow(() -> new IllegalArgumentException("Friend request not found"));
        friendshipRepository.delete(request);
        logger.info("Friend request {} declined by {}", requestId, selfId);
    }

    public FriendListResponse getFriends(String email) {
        UUID selfId = requireUser(email).getId();
        List<Friendship> accepted = friendshipRepository.findByStatusInvolving(selfId, FriendshipStatus.ACCEPTED);
        LocalDate today = LocalDate.now();

        List<FriendSummaryResponse> friends = accepted.stream()
                .map(f -> f.getRequesterId().equals(selfId) ? f.getAddresseeId() : f.getRequesterId())
                .map(friendId -> {
                    DailySteps todayEntry = dailyStepsRepository
                            .findByUserIdAndStepDate(friendId, today)
                            .orElse(null);
                    return FriendSummaryResponse.builder()
                            .friendUserId(friendId)
                            .fullName(fullNameOf(friendId))
                            .todaySteps(todayEntry != null ? todayEntry.getStepCount() : 0)
                            .todayActiveMinutes(todayEntry != null ? todayEntry.getActiveMinutes() : 0)
                            .build();
                })
                .collect(Collectors.toList());
        return FriendListResponse.builder().friends(friends).build();
    }

    @Transactional
    public void unfriend(String email, UUID friendUserId) {
        UUID selfId = requireUser(email).getId();
        int deleted = friendshipRepository.deleteByStatusBetween(selfId, friendUserId, FriendshipStatus.ACCEPTED);
        if (deleted == 0) {
            throw new IllegalArgumentException("Not friends with this user");
        }
        logger.info("Friendship removed between {} and {}", selfId, friendUserId);
    }

    private String fullNameOf(UUID userId) {
        return userProfileRepository.findById(userId)
                .map(UserProfile::getFullName)
                .filter(name -> name != null && !name.isBlank())
                .orElse("Unknown user");
    }

    private User requireUser(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

    /**
     * @return the signed-in user's email, or null if nobody is signed in. Anonymous
     *         authentication counts as signed out - {@code isAuthenticated()} is true for
     *         an {@link AnonymousAuthenticationToken}, whose name is "anonymousUser".
     */
    public String getCurrentUserEmail() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {
            return null;
        }
        return authentication.getName();
    }
}
