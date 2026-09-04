package com.steptrack.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Min;
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

    private String fullName;

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
