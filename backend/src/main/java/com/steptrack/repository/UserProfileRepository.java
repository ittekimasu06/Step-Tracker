package com.steptrack.repository;

import com.steptrack.model.UserProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface UserProfileRepository extends JpaRepository<UserProfile, UUID> {

    /**
     * Friend search: matches non-null {@code fullName}s containing {@code query}
     * (case-insensitive), excluding the caller, capped at 20 results - see
     * {@code FriendshipService} for why (unthrottled name search would let any
     * authenticated user enumerate the whole user base).
     */
    List<UserProfile> findTop20ByFullNameContainingIgnoreCaseAndIdNot(String query, UUID selfId);
}
