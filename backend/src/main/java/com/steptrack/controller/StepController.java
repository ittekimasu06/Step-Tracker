package com.steptrack.controller;

import com.steptrack.dto.HourlyStepsListResponse;
import com.steptrack.dto.HourlyStepsUpdateRequest;
import com.steptrack.dto.StepEntryRequest;
import com.steptrack.dto.StepEntryResponse;
import com.steptrack.service.StepService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/steps")
@RequiredArgsConstructor
public class StepController {

    private static final Logger logger = LoggerFactory.getLogger(StepController.class);

    private final StepService stepService;

    @GetMapping("/{date}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<StepEntryResponse> getSteps(@PathVariable String date) {
        try {
            String email = stepService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            StepEntryResponse steps = stepService.getSteps(email, date);
            logger.debug("Steps retrieved for user: {} on {}", email, date);
            return ResponseEntity.ok(steps);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid steps request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (Exception e) {
            logger.error("Error retrieving steps", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{date}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<StepEntryResponse> saveSteps(
            @PathVariable String date, @Valid @RequestBody StepEntryRequest request) {
        try {
            String email = stepService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            StepEntryResponse updated = stepService.saveSteps(email, date, request);
            logger.info("Steps updated for user: {} on {}", email, date);
            return ResponseEntity.ok(updated);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid steps update: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (Exception e) {
            logger.error("Error updating steps", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{date}/hours")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<HourlyStepsListResponse> getHourlySteps(@PathVariable String date) {
        try {
            String email = stepService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            HourlyStepsListResponse hours = stepService.getHourlySteps(email, date);
            logger.debug("Hourly steps retrieved for user: {} on {}", email, date);
            return ResponseEntity.ok(hours);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid hourly steps request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (Exception e) {
            logger.error("Error retrieving hourly steps", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{date}/hours")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<HourlyStepsListResponse> saveHourlySteps(
            @PathVariable String date, @Valid @RequestBody HourlyStepsUpdateRequest request) {
        try {
            String email = stepService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            HourlyStepsListResponse updated = stepService.saveHourlySteps(email, date, request);
            logger.info("Hourly steps updated for user: {} on {}", email, date);
            return ResponseEntity.ok(updated);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid hourly steps update: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (Exception e) {
            logger.error("Error updating hourly steps", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
