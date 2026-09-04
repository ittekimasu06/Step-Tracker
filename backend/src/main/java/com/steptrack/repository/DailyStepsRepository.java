package com.steptrack.repository;

import com.steptrack.model.DailySteps;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface DailyStepsRepository extends JpaRepository<DailySteps, UUID> {
    Optional<DailySteps> findByUserIdAndStepDate(UUID userId, LocalDate stepDate);
    void deleteByUserId(UUID userId);
}
