package com.steptrack.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HourlyStepEntryRequest {

    @NotNull(message = "Hour of day is required")
    @Min(value = 0, message = "Hour of day must be between 0 and 23")
    @Max(value = 23, message = "Hour of day must be between 0 and 23")
    private Integer hourOfDay;

    @NotNull(message = "Step count is required")
    @Min(value = 0, message = "Step count cannot be negative")
    private Integer stepCount;

    @NotNull(message = "Active minutes is required")
    @Min(value = 0, message = "Active minutes cannot be negative")
    private Integer activeMinutes;
}
