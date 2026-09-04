package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StepEntryResponse {

    private LocalDate date;
    private Integer stepCount;
    private Integer activeMinutes;
    private LocalDateTime updatedAt;
}
