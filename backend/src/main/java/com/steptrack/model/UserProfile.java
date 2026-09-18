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

    /**
     * Unique (case-insensitively - enforced by a unique index on lower(username), not
     * just the plain column) display handle. Required at registration, unlike every
     * other field here which is filled in later during profile-setup.
     */
    @Column(unique = true)
    private String username;

    @Column(name = "full_name")
    private String fullName;

    @Column(length = 500)
    private String description;

    /**
     * Null (never explicitly chosen - every pre-existing row) or the literal string
     * "default" (explicitly re-selected in the picker) both mean the initials-gradient
     * avatar (this app's only look until this field existed). Any other value is a
     * bundled asset identifier (a filename under assets/images/, e.g.
     * "avatar_horse.png") to show instead. The picker always sends the literal
     * "default" string rather than null for that option, since {@link
     * com.steptrack.service.ProfileService#saveProfile}'s partial-update convention
     * treats a null request field as "unchanged," not "clear this" - there would
     * otherwise be no way to go back to the default once a real avatar was chosen.
     */
    @Column(name = "avatar_id")
    private String avatarId;

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
