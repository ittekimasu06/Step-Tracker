package com.steptrack.service;

import com.steptrack.dto.LoginRequest;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.model.User;
import com.steptrack.repository.UserRepository;
import com.steptrack.security.JwtProvider;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;

    @Transactional
    public String register(RegisterRequest request) {
        // Validate passwords match
        if (!request.getPassword().equals(request.getPasswordConfirm())) {
            logger.warn("Registration failed: passwords do not match for {}", request.getEmail());
            throw new IllegalArgumentException("Passwords do not match");
        }

        // Check if email already exists
        if (userRepository.existsByEmail(request.getEmail())) {
            logger.warn("Registration failed: email already exists {}", request.getEmail());
            throw new IllegalArgumentException("Email already registered");
        }

        // Create new user
        User user = User.builder()
                .id(UUID.randomUUID())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        userRepository.save(user);
        logger.info("New user registered: {}", request.getEmail());

        // Generate JWT token
        return jwtProvider.generateToken(user.getEmail());
    }

    public String login(LoginRequest request) {
        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> {
                    logger.warn("Login failed: user not found {}", request.getEmail());
                    return new BadCredentialsException("Invalid email or password");
                });

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            logger.warn("Login failed: invalid password for {}", request.getEmail());
            throw new BadCredentialsException("Invalid email or password");
        }

        logger.info("User logged in: {}", request.getEmail());
        return jwtProvider.generateToken(user.getEmail());
    }

    public String loginWithGoogle(String email) {
        User user = userRepository.findByEmail(email)
                .orElseGet(() -> {
                    // Create new user if doesn't exist
                    logger.info("Creating new user from Google OAuth: {}", email);
                    User newUser = User.builder()
                            .id(UUID.randomUUID())
                            .email(email)
                            .passwordHash("") // Google auth doesn't use password
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();
                    return userRepository.save(newUser);
                });

        logger.info("Google login successful for: {}", email);
        return jwtProvider.generateToken(user.getEmail());
    }
}
