package com.steptrack.repository;

import com.steptrack.model.DailySteps;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DailyStepsRepository extends JpaRepository<DailySteps, UUID> {
    Optional<DailySteps> findByUserIdAndStepDate(UUID userId, LocalDate stepDate);
    List<DailySteps> findByUserIdAndStepDateGreaterThanEqualOrderByStepDateAsc(UUID userId, LocalDate from);
    void deleteByUserId(UUID userId);

    /**
     * Total steps for {@code userId} across [from, to] inclusive - for the friends
     * leaderboard. A scalar aggregate with no GROUP BY always returns exactly one row
     * even when zero {@code daily_steps} rows match (SUM is then NULL, COALESCE makes it
     * 0) - this is deliberate so a friend with no activity in the period still appears
     * ranked at 0 rather than being silently dropped. Do NOT "optimize" this to a
     * GROUP BY user_id query across multiple users at once - that form omits any user
     * with zero matching rows entirely, reintroducing exactly the bug this avoids.
     */
    @Query("SELECT COALESCE(SUM(d.stepCount), 0) FROM DailySteps d "
            + "WHERE d.userId = :userId AND d.stepDate BETWEEN :from AND :to")
    int sumStepsBetween(@Param("userId") UUID userId, @Param("from") LocalDate from, @Param("to") LocalDate to);
}
