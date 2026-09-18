package com.steptrack.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfileRequest {

    @Email(message = "Email must be valid")
    private String email;

    @Size(min = 3, max = 50, message = "Username must be between 3 and 50 characters")
    @Pattern(regexp = "^[a-zA-Z0-9_]+$", message = "Username may only contain letters, numbers, and underscores")
    private String username;

    private String fullName;

    @Size(max = 500, message = "Description cannot exceed 500 characters")
    private String description;

    private String avatarId;

    private Integer age;

    private BigDecimal weightKg;

    private BigDecimal heightCm;

    private String gender;

    private Boolean profileCompleted;

    @Min(value = 0, message = "Step goal cannot be negative")
    private Integer stepGoal;

    @Min(value = 0, message = "Active minutes goal cannot be negative")
    private Integer activeMinutesGoal;

    @Min(value = 0, message = "Calorie goal cannot be negative")
    private Integer calorieGoal;
}
