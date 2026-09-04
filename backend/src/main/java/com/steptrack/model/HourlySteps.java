package com.steptrack.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * One row per user per calendar day per hour-of-day (0-23), holding that hour's step count
 * and active minutes. Only a trailing window of these is kept - see
 * {@link com.steptrack.service.StepService#purgeOldHourlyData()} - the client always sends
 * its own authoritative per-hour totals, same as {@link DailySteps}.
 */
@Entity
@Table(name = "hourly_steps", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "step_date", "hour_of_day"}))
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HourlySteps {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "step_date", nullable = false)
    private LocalDate stepDate;

    @Column(name = "hour_of_day", nullable = false)
    private Integer hourOfDay;

    @Builder.Default
    @Column(name = "step_count", nullable = false)
    private Integer stepCount = 0;

    @Builder.Default
    @Column(name = "active_minutes", nullable = false)
    private Integer activeMinutes = 0;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
