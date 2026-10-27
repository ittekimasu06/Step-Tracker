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
 * A frozen snapshot of one user's progress on {@code postDate}, shared to their friends'
 * Connect feed. Deliberately stores both the numerator ({@code stepCount}/{@code
 * activeMinutes}/{@code calorieCount}) and the denominator ({@code stepGoal}/{@code
 * activeMinutesGoal}/{@code calorieGoal}) as they were at share time, rather than a live
 * reference to the day's {@link DailySteps} row and the user's current profile goals - a
 * goal changed later, or more steps walked later that same day, must never silently reshape
 * an already-shared post (see {@code PostService.createPost}).
 */
@Entity
@Table(name = "posts")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Post {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "post_date", nullable = false)
    private LocalDate postDate;

    @Column(name = "step_count", nullable = false)
    private Integer stepCount;

    @Column(name = "step_goal", nullable = false)
    private Integer stepGoal;

    @Column(name = "active_minutes", nullable = false)
    private Integer activeMinutes;

    @Column(name = "active_minutes_goal", nullable = false)
    private Integer activeMinutesGoal;

    @Column(name = "calorie_count", nullable = false)
    private Integer calorieCount;

    @Column(name = "calorie_goal", nullable = false)
    private Integer calorieGoal;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
