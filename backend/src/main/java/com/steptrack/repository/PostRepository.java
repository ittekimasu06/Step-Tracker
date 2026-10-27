package com.steptrack.repository;

import com.steptrack.model.Post;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface PostRepository extends JpaRepository<Post, UUID> {

    /**
     * The Connect feed query - {@code userIds} is always the caller's own id plus their
     * accepted friends' ids (derived the same way {@code FriendshipService.getLeaderboard}
     * derives its participant list), so a post is only ever visible to the people it was
     * actually shared with.
     */
    Page<Post> findByUserIdInOrderByCreatedAtDesc(List<UUID> userIds, Pageable pageable);
}
