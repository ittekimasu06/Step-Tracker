package com.steptrack.controller;

import com.steptrack.dto.AuthResponse;
import com.steptrack.dto.GoogleAuthRequest;
import com.steptrack.dto.LoginRequest;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.security.GoogleTokenVerifier;
import com.steptrack.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
public class AuthController {

    private static final Logger logger = LoggerFactory.getLogger(AuthController.class);

    private final AuthService authService;
    private final GoogleTokenVerifier googleTokenVerifier;

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        try {
            String token = authService.register(request);
            logger.info("User registered successfully: {}", request.getEmail());
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(AuthResponse.builder()
                            .token(token)
                            .email(request.getEmail())
                            .message("Registration successful")
                            .build());
        } catch (IllegalArgumentException e) {
            logger.warn("Registration failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(AuthResponse.builder()
                            .message(e.getMessage())
                            .build());
        } catch (Exception e) {
            logger.error("Unexpected error during registration", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(AuthResponse.builder()
                            .message("Registration failed")
                            .build());
        }
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        try {
            String token = authService.login(request);
            logger.info("User logged in successfully: {}", request.getEmail());
            return ResponseEntity.ok(AuthResponse.builder()
                    .token(token)
                    .email(request.getEmail())
                    .message("Login successful")
                    .build());
        } catch (BadCredentialsException e) {
            logger.warn("Login failed for email: {}", request.getEmail());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(AuthResponse.builder()
                            .message("Invalid credentials")
                            .build());
        } catch (Exception e) {
            logger.error("Unexpected error during login", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(AuthResponse.builder()
                            .message("Login failed")
                            .build());
        }
    }

    @PostMapping("/google")
    public ResponseEntity<AuthResponse> loginWithGoogle(@Valid @RequestBody GoogleAuthRequest request) {
        try {
            if (request.getIdToken() == null || request.getIdToken().isEmpty()) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(AuthResponse.builder()
                            .message("ID token is required")
                            .build());
            }

            // Verify Google ID token and extract email
            String email = googleTokenVerifier.verifyAndExtractEmail(request.getIdToken());
            
            // Create or authenticate user
            String token = authService.loginWithGoogle(email);
            
            return ResponseEntity.ok(AuthResponse.builder()
                    .token(token)
                    .email(email)
                    .message("Google login successful")
                    .build());
        } catch (IllegalArgumentException e) {
            logger.warn("Google authentication failed: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(AuthResponse.builder()
                            .message(e.getMessage())
                            .build());
        } catch (IllegalStateException e) {
            logger.error("Google sign-in is not configured: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                    .body(AuthResponse.builder()
                            .message(e.getMessage())
                            .build());
        } catch (Exception e) {
            logger.error("Unexpected error during Google authentication", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(AuthResponse.builder()
                            .message("Google authentication failed")
                            .build());
        }
    }

    @PostMapping("/logout")
    public ResponseEntity<AuthResponse> logout() {
        return ResponseEntity.ok(AuthResponse.builder()
                .message("Logged out successfully")
                .build());
    }
}
