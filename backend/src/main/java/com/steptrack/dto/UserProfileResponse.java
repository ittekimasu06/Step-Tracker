package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserProfileResponse {

    private UUID id;
    private String email;
    private String fullName;
    private Integer age;
    private BigDecimal weightKg;
    private BigDecimal heightCm;
    private String gender;
    private Boolean profileCompleted;
    private Integer stepGoal;
    private Integer activeMinutesGoal;
    private Integer calorieGoal;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
