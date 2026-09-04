package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HourlyStepEntryResponse {

    private Integer hourOfDay;
    private Integer stepCount;
    private Integer activeMinutes;
}
