package com.steptrack.controller;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.ChangeEmailRequest;
import com.steptrack.dto.ConfirmEmailChangeRequest;
import com.steptrack.dto.UserProfileRequest;
import com.steptrack.dto.UserProfileResponse;
import com.steptrack.service.AuthService;
import com.steptrack.service.ProfileService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/profile")
@RequiredArgsConstructor
public class ProfileController {

    private static final Logger logger = LoggerFactory.getLogger(ProfileController.class);

    private final ProfileService profileService;
    private final AuthService authService;

    @GetMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<UserProfileResponse> getProfile() {
        try {
            String email = profileService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }
            
            UserProfileResponse profile = profileService.getProfile(email);
            logger.debug("Profile retrieved for user: {}", email);
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            logger.error("Error retrieving profile", e);
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }
    }

    /**
     * Return type is {@code ResponseEntity<?>}, not the usual
     * {@code ResponseEntity<UserProfileResponse>} - like {@code ConsultantController}/
     * {@code FriendController}, the 400 here carries a real {@code message} (e.g.
     * "Username already taken") so the client can show it verbatim instead of a
     * generic failure - a bare {@code .build()} would silently swallow exactly the
     * detail a username-collision error needs to be useful.
     */
    @PutMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> updateProfile(@Valid @RequestBody UserProfileRequest request) {
        try {
            String email = profileService.getCurrentUserEmail();
            if (email == null) {
                logger.warn("No authenticated user found");
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
            }

            UserProfileResponse updatedProfile = profileService.saveProfile(email, request);
            logger.info("Profile updated for user: {}", email);
            return ResponseEntity.ok(updatedProfile);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid profile update: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error updating profile", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<Void> deleteAccount() {
        String email = profileService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            profileService.deleteAccount(email);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            logger.warn("Account deletion failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).build();
        } catch (Exception e) {
            logger.error("Error deleting account", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/email/change")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> changeEmail(@Valid @RequestBody ChangeEmailRequest request) {
        String email = profileService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            authService.requestEmailChange(email, request.getCurrentPassword(), request.getNewEmail());
            return ResponseEntity.ok(Map.of("message", "Verification code sent to new email"));
        } catch (BadCredentialsException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("message", e.getMessage()));
        } catch (IllegalArgumentException e) {
            logger.warn("Email change request failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error requesting email change", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/email/confirm")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> confirmEmailChange(@Valid @RequestBody ConfirmEmailChangeRequest request) {
        String email = profileService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            String token = authService.confirmEmailChange(email, request.getCode());
            return ResponseEntity.ok(AuthResponse.builder()
                    .token(token)
                    .message("Email changed")
                    .build());
        } catch (IllegalArgumentException e) {
            logger.warn("Email change confirmation failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error confirming email change", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/email/resend")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> resendEmailChangeCode() {
        String email = profileService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        try {
            authService.resendEmailChangeCode(email);
            return ResponseEntity.ok(Map.of("message", "Verification code resent"));
        } catch (IllegalArgumentException e) {
            logger.warn("Resend email change code failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error resending email change code", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}
