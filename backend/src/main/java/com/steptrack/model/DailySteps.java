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
 * One row per user per calendar day, holding that day's step count. The client always
 * sends its own authoritative total for "today" (in its own local timezone) - the server
 * does not try to reconcile timezones or accumulate deltas.
 */
@Entity
@Table(name = "daily_steps", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "step_date"}))
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DailySteps {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "step_date", nullable = false)
    private LocalDate stepDate;

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
