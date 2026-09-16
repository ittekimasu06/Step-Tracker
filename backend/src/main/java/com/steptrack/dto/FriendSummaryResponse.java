package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FriendSummaryResponse {

    private UUID friendUserId;
    private String fullName;
    private int todaySteps;
    private int todayActiveMinutes;
}
