package com.steptrack.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * The {@code @Valid} on {@link #hours} is what makes each list entry's own field-level
 * validation actually run - a bare {@code List<T>} request-body parameter does not cascade
 * {@code @Valid} into its elements on its own.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class HourlyStepsUpdateRequest {

    @NotEmpty(message = "At least one hour is required")
    @Valid
    private List<HourlyStepEntryRequest> hours;
}
