package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PostResponse {

    private UUID id;
    private UUID userId;
    private String fullName;
    private String username;
    private String avatarId;
    private LocalDate postDate;
    private Integer stepCount;
    private Integer stepGoal;
    private Integer activeMinutes;
    private Integer activeMinutesGoal;
    private Integer calorieCount;
    private Integer calorieGoal;
    private long likeCount;
    private boolean likedByMe;
    private LocalDateTime createdAt;
}
