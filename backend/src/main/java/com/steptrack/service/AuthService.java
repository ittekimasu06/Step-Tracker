package com.steptrack.service;

import com.steptrack.dto.LoginRequest;
import com.steptrack.dto.RegisterRequest;
import com.steptrack.model.User;
import com.steptrack.model.UserProfile;
import com.steptrack.repository.UserProfileRepository;
import com.steptrack.repository.UserRepository;
import com.steptrack.security.JwtProvider;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Lazy;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class AuthService {

    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;

    // Self-injected (lazily, to avoid a circular-eager-init error) so
    // createUserInNewTransaction's @Transactional(REQUIRES_NEW) actually goes
    // through the Spring proxy - a direct `this.createUserInNewTransaction(...)`
    // call would bypass the proxy entirely (a well-known Spring AOP limitation)
    // and silently run in the caller's existing transaction instead. Written out
    // by hand (no @RequiredArgsConstructor) since Lombok copying @Lazy onto the
    // generated constructor parameter isn't guaranteed.
    private final AuthService self;

    public AuthService(
            UserRepository userRepository,
            UserProfileRepository userProfileRepository,
            PasswordEncoder passwordEncoder,
            JwtProvider jwtProvider,
            @Lazy AuthService self) {
        this.userRepository = userRepository;
        this.userProfileRepository = userProfileRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtProvider = jwtProvider;
        this.self = self;
    }

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

        // Check if username already exists (case-insensitively)
        if (userProfileRepository.existsByUsernameIgnoreCase(request.getUsername())) {
            logger.warn("Registration failed: username already exists {}", request.getUsername());
            throw new IllegalArgumentException("Username already taken");
        }

        // Created and committed in its own, already-closed transaction (see
        // createUserInNewTransaction) before the user_profiles insert below even
        // starts - a same-transaction flush() was tried first and did NOT fix this
        // (confirmed by testing): Hibernate has no JPA-level relationship mapped
        // between User and UserProfile (they only share an id value, the FK only
        // exists in the raw DDL, invisible to Hibernate's order_inserts dependency
        // detection), so its per-entity-type batching can still flush the
        // user_profiles insert before the users insert within one flush/commit,
        // violating the FK. A real, separate committed transaction sidesteps that
        // entirely regardless of batching/ordering behavior.
        User user = self.createUserInNewTransaction(request);

        // Unlike every other profile field (filled in later during profile-setup),
        // username must be captured at registration time, so a starter UserProfile
        // row is created here instead of relying on ProfileService's lazy-create
        // fallback - that fallback still exists and still fires for accounts created
        // before this field existed, and for Google sign-in (see loginWithGoogle).
        UserProfile profile = UserProfile.builder()
                .id(user.getId())
                .username(request.getUsername())
                .profileCompleted(false)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        userProfileRepository.save(profile);

        logger.info("New user registered: {}", request.getEmail());

        // Generate JWT token
        return jwtProvider.generateToken(user.getEmail());
    }

    /**
     * Runs in its own, independently-committed transaction - see the comment at
     * this method's call site in {@link #register} for why. Must be called via
     * {@code self.createUserInNewTransaction(...)}, never {@code this.}, or the
     * {@code REQUIRES_NEW} propagation silently does nothing (self-invocation
     * bypasses the Spring proxy that implements it).
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public User createUserInNewTransaction(RegisterRequest request) {
        User user = User.builder()
                .id(UUID.randomUUID())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();
        return userRepository.save(user);
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
