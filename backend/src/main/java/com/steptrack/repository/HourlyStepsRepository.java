package com.steptrack.repository;

import com.steptrack.model.HourlySteps;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface HourlyStepsRepository extends JpaRepository<HourlySteps, UUID> {
    Optional<HourlySteps> findByUserIdAndStepDateAndHourOfDay(UUID userId, LocalDate stepDate, Integer hourOfDay);
    List<HourlySteps> findByUserIdAndStepDateOrderByHourOfDay(UUID userId, LocalDate stepDate);
    void deleteByUserId(UUID userId);
    void deleteByStepDateBefore(LocalDate cutoff);
}
