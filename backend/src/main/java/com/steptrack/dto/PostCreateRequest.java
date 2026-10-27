package com.steptrack.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * {@code stepCount}/{@code activeMinutes}/goals are all read server-side from the caller's
 * own stored data at share time (see {@code PostService.createPost}) - never accepted from
 * the client, the same "never trust a cross-cutting number the client could have forged"
 * posture the rest of this app takes. {@code calorieCount} is the one exception: unlike
 * steps/active minutes, calories have no raw stored value anywhere - they're derived via a
 * MET-based formula ({@code ActivityEstimator.activityCalories}) that only exists on the
 * Flutter side, which already computes and displays this exact number live on the dashboard
 * at the moment of sharing. Porting that formula to the backend too would mean keeping two
 * independent implementations of the same tuned, documented formula in sync forever; trusting
 * the client for this one low-stakes display number (not money, not access control) is the
 * better trade.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostCreateRequest {

    @NotNull(message = "Calorie count is required")
    @Min(value = 0, message = "Calorie count cannot be negative")
    private Integer calorieCount;
}
