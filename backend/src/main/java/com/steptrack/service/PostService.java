package com.steptrack.service;

import com.steptrack.dto.PostFeedResponse;
import com.steptrack.dto.PostResponse;
import com.steptrack.model.DailySteps;
import com.steptrack.model.Post;
import com.steptrack.model.PostLike;
import com.steptrack.model.User;
import com.steptrack.model.UserProfile;
import com.steptrack.repository.DailyStepsRepository;
import com.steptrack.repository.FriendshipRepository;
import com.steptrack.repository.PostLikeRepository;
import com.steptrack.repository.PostRepository;
import com.steptrack.repository.UserProfileRepository;
import com.steptrack.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

import static com.steptrack.model.Friendship.FriendshipStatus.ACCEPTED;

/**
 * Friends-only progress-sharing posts (the Connect tab's feed) - see {@link Post}'s doc for
 * why a post is a frozen snapshot rather than a live reference. Shares {@link
 * FriendshipRepository}'s "friend ids involving self" pattern with {@code
 * FriendshipService.getLeaderboard}, and the same "never accept an unchecked cross-user id"
 * posture {@code FriendshipService}'s class doc establishes - {@link #like}/{@link #unlike}
 * independently re-derive whether the caller may act on a post rather than trusting that a
 * {@code postId} the client sent was something it legitimately saw in its own feed.
 */
@Service
@RequiredArgsConstructor
public class PostService {

    private static final Logger logger = LoggerFactory.getLogger(PostService.class);
    private static final int FEED_PAGE_SIZE = 20;

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final DailyStepsRepository dailyStepsRepository;
    private final FriendshipRepository friendshipRepository;
    private final PostRepository postRepository;
    private final PostLikeRepository postLikeRepository;

    @Transactional
    public PostResponse createPost(String email, Integer calorieCount) {
        User self = requireUser(email);
        UserProfile profile = profileOf(self.getId());
        LocalDate today = LocalDate.now();
        DailySteps todayEntry = dailyStepsRepository.findByUserIdAndStepDate(self.getId(), today).orElse(null);

        Post post = postRepository.save(Post.builder()
                .userId(self.getId())
                .postDate(today)
                .stepCount(todayEntry != null ? todayEntry.getStepCount() : 0)
                .stepGoal(goalOrDefault(profile != null ? profile.getStepGoal() : null, 6000))
                .activeMinutes(todayEntry != null ? todayEntry.getActiveMinutes() : 0)
                .activeMinutesGoal(goalOrDefault(profile != null ? profile.getActiveMinutesGoal() : null, 90))
                .calorieCount(calorieCount)
                .calorieGoal(goalOrDefault(profile != null ? profile.getCalorieGoal() : null, 500))
                .build());

        logger.info("Post created by {} for {}", email, today);
        return toResponse(post, self.getId(), profile);
    }

    public PostFeedResponse getFeed(String email, int page) {
        UUID selfId = requireUser(email).getId();
        List<UUID> participantIds = friendshipRepository.findByStatusInvolving(selfId, ACCEPTED).stream()
                .map(f -> f.getRequesterId().equals(selfId) ? f.getAddresseeId() : f.getRequesterId())
                .collect(Collectors.toList());
        participantIds.add(selfId);

        Page<Post> result = postRepository.findByUserIdInOrderByCreatedAtDesc(
                participantIds, PageRequest.of(Math.max(page, 0), FEED_PAGE_SIZE));

        List<PostResponse> posts = result.getContent().stream()
                .map(post -> toResponse(post, selfId, profileOf(post.getUserId())))
                .collect(Collectors.toList());
        return PostFeedResponse.builder().posts(posts).hasMore(result.hasNext()).build();
    }

    @Transactional
    public void like(String email, UUID postId) {
        UUID selfId = requireUser(email).getId();
        Post post = requirePost(postId);
        requireCanView(selfId, post.getUserId());

        if (postLikeRepository.existsByPostIdAndUserId(postId, selfId)) {
            return;
        }
        postLikeRepository.save(PostLike.builder().postId(postId).userId(selfId).build());
    }

    @Transactional
    public void unlike(String email, UUID postId) {
        UUID selfId = requireUser(email).getId();
        requirePost(postId);
        postLikeRepository.deleteByPostIdAndUserId(postId, selfId);
    }

    /**
     * A post is only ever likeable by its own author or an accepted friend of theirs - the
     * exact same boundary that already decides whether a post even appears in someone's feed
     * (see {@link #getFeed}), re-checked here independently rather than trusted from the
     * client, since a {@code postId} arrives as a bare path variable with no proof it came
     * from the caller's own feed response.
     */
    private void requireCanView(UUID selfId, UUID postAuthorId) {
        if (selfId.equals(postAuthorId)) {
            return;
        }
        boolean areFriends =
                friendshipRepository.existsByRequesterIdAndAddresseeIdAndStatus(selfId, postAuthorId, ACCEPTED)
                        || friendshipRepository.existsByRequesterIdAndAddresseeIdAndStatus(postAuthorId, selfId, ACCEPTED);
        if (!areFriends) {
            throw new IllegalArgumentException("Post not found");
        }
    }

    private Post requirePost(UUID postId) {
        return postRepository.findById(postId)
                .orElseThrow(() -> new IllegalArgumentException("Post not found"));
    }

    private PostResponse toResponse(Post post, UUID viewerId, UserProfile authorProfile) {
        return PostResponse.builder()
                .id(post.getId())
                .userId(post.getUserId())
                .fullName(displayName(authorProfile))
                .username(authorProfile != null ? authorProfile.getUsername() : null)
                .avatarId(authorProfile != null ? authorProfile.getAvatarId() : null)
                .postDate(post.getPostDate())
                .stepCount(post.getStepCount())
                .stepGoal(post.getStepGoal())
                .activeMinutes(post.getActiveMinutes())
                .activeMinutesGoal(post.getActiveMinutesGoal())
                .calorieCount(post.getCalorieCount())
                .calorieGoal(post.getCalorieGoal())
                .likeCount(postLikeRepository.countByPostId(post.getId()))
                .likedByMe(postLikeRepository.existsByPostIdAndUserId(post.getId(), viewerId))
                .createdAt(post.getCreatedAt())
                .build();
    }

    private int goalOrDefault(Integer goal, int fallback) {
        return goal != null ? goal : fallback;
    }

    private UserProfile profileOf(UUID userId) {
        return userProfileRepository.findById(userId).orElse(null);
    }

    private String displayName(UserProfile profile) {
        String name = profile != null ? profile.getFullName() : null;
        return (name != null && !name.isBlank()) ? name : "Unknown user";
    }

    private User requireUser(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }

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
