package com.steptrack.dto;

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
public class StepEntryRequest {

    @NotNull(message = "Step count is required")
    @Min(value = 0, message = "Step count cannot be negative")
    private Integer stepCount;

    @NotNull(message = "Active minutes is required")
    @Min(value = 0, message = "Active minutes cannot be negative")
    private Integer activeMinutes;
}
