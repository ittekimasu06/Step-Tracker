package com.steptrack.repository;

import com.steptrack.model.Friendship;
import com.steptrack.model.Friendship.FriendshipStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface FriendshipRepository extends JpaRepository<Friendship, UUID> {

    Optional<Friendship> findByRequesterIdAndAddresseeId(UUID requesterId, UUID addresseeId);

    /**
     * Scoped so the addressee cannot be spoofed - only ever finds a PENDING request that
     * actually belongs to {@code addresseeId}. Used by accept/decline so "not found" and
     * "not yours" are indistinguishable to the caller (both return empty).
     */
    Optional<Friendship> findByIdAndAddresseeIdAndStatus(UUID id, UUID addresseeId, FriendshipStatus status);

    List<Friendship> findByAddresseeIdAndStatus(UUID addresseeId, FriendshipStatus status);

    List<Friendship> findByRequesterIdAndStatus(UUID requesterId, FriendshipStatus status);

    /**
     * Scoped so the requester cannot be spoofed - only ever finds a PENDING request that
     * was actually sent by {@code requesterId}. Used to cancel a sent request, same
     * "not found" / "not yours" indistinguishability as {@link #findByIdAndAddresseeIdAndStatus}.
     */
    Optional<Friendship> findByIdAndRequesterIdAndStatus(UUID id, UUID requesterId, FriendshipStatus status);

    /**
     * Every friendship of {@code status} involving {@code selfId}, on either side - the
     * sole source of "who is my friend" the rest of the app is allowed to derive another
     * user's UUID from.
     */
    @Query("SELECT f FROM Friendship f WHERE f.status = :status "
            + "AND (f.requesterId = :selfId OR f.addresseeId = :selfId)")
    List<Friendship> findByStatusInvolving(@Param("selfId") UUID selfId, @Param("status") FriendshipStatus status);

    @Modifying
    @Query("DELETE FROM Friendship f WHERE f.status = :status "
            + "AND ((f.requesterId = :selfId AND f.addresseeId = :otherId) "
            + "OR (f.requesterId = :otherId AND f.addresseeId = :selfId))")
    int deleteByStatusBetween(
            @Param("selfId") UUID selfId,
            @Param("otherId") UUID otherId,
            @Param("status") FriendshipStatus status);

    boolean existsByRequesterIdAndAddresseeIdAndStatus(UUID requesterId, UUID addresseeId, FriendshipStatus status);
}
