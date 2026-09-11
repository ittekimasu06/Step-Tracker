package com.steptrack.controller;

import com.steptrack.dto.ConsultantAdviceResponse;
import com.steptrack.service.ConsultantService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/consultant")
@RequiredArgsConstructor
public class ConsultantController {

    private static final Logger logger = LoggerFactory.getLogger(ConsultantController.class);

    private final ConsultantService consultantService;

    /**
     * Return type is intentionally {@code ResponseEntity<?>}, not the usual
     * {@code ResponseEntity<ConsultantAdviceResponse>} - unlike every other controller's bare
     * {@code .build()} error responses, the 400 here carries a real {@code message} (the
     * cooldown text) so the client can show it as-is instead of a generic failure message.
     * The Flutter app's {@code ApiClient} already reads a {@code message} field from an
     * error body when present; this is the first backend endpoint to actually send one.
     */
    @PostMapping("/advice")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getAdvice() {
        try {
            String email = consultantService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            String advice = consultantService.getAdvice(email);
            logger.info("Consultant advice requested by user: {}", email);
            return ResponseEntity.ok(ConsultantAdviceResponse.builder().advice(advice).build());
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid consultant advice request: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error generating consultant advice", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
