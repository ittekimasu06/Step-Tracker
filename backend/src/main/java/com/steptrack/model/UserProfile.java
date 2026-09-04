package com.steptrack.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Profile data for a user. Shares its primary key with {@link User} - the {@code id}
 * column is both the PK and the FK to {@code users(id)}.
 */
@Entity
@Table(name = "user_profiles")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfile {

    @Id
    private UUID id;

    @Column(name = "full_name")
    private String fullName;

    @Column
    private Integer age;

    @Column(name = "weight_kg")
    private BigDecimal weightKg;

    @Column(name = "height_cm")
    private BigDecimal heightCm;

    @Column
    private String gender;

    @Builder.Default
    @Column(name = "profile_completed")
    private Boolean profileCompleted = false;

    @Column(name = "step_goal")
    private Integer stepGoal;

    @Column(name = "active_minutes_goal")
    private Integer activeMinutesGoal;

    @Column(name = "calorie_goal")
    private Integer calorieGoal;

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
