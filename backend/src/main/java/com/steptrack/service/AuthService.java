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

import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AuthService {

    private static final Logger logger = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final long VERIFICATION_CODE_TTL_MINUTES = 15;
    private static final long RESEND_COOLDOWN_SECONDS = 60;

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtProvider jwtProvider;
    private final EmailService emailService;

    // Same cooldown-map shape as ConsultantService - keyed by email (not a UUID; a resend
    // request can arrive for an email whose User row exists but isn't verified yet, which is
    // the only state this throttle actually needs to cover).
    private final Map<String, Instant> lastResendAt = new ConcurrentHashMap<>();

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
            EmailService emailService,
            @Lazy AuthService self) {
        this.userRepository = userRepository;
        this.userProfileRepository = userProfileRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtProvider = jwtProvider;
        this.emailService = emailService;
        this.self = self;
    }

    /**
     * Unlike before email verification existed, this no longer returns a usable session - the
     * account isn't ready to be logged into until {@link #verifyEmail} succeeds. The caller
     * (AuthController) responds with {@code requiresVerification: true} and no token.
     */
    @Transactional
    public void register(RegisterRequest request) {
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

        issueAndSendVerificationCode(user, user.getEmail());

        logger.info("New user registered: {}", request.getEmail());
    }

    /**
     * Generates a fresh code, persists it with a new expiry, and emails it to [targetEmail] -
     * not always {@code user.getEmail()}: email-change confirmation (see {@link
     * #requestEmailChange}) sends it to the pending new address instead, while the code itself
     * still lives on the same row.
     */
    private void issueAndSendVerificationCode(User user, String targetEmail) {
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        user.setVerificationCode(code);
        user.setVerificationCodeExpiresAt(LocalDateTime.now().plusMinutes(VERIFICATION_CODE_TTL_MINUTES));
        userRepository.save(user);
        emailService.sendVerificationCode(targetEmail, code);
    }

    /** Throws if [user]'s stored code doesn't match [code] or has expired. */
    private void validateVerificationCode(User user, String code) {
        if (user.getVerificationCode() == null || !user.getVerificationCode().equals(code)) {
            throw new IllegalArgumentException("Incorrect verification code");
        }
        if (user.getVerificationCodeExpiresAt() == null
                || user.getVerificationCodeExpiresAt().isBefore(LocalDateTime.now())) {
            throw new IllegalArgumentException("Verification code has expired - request a new one");
        }
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
                // Overrides the entity's fail-open default (see User.emailVerified's doc) -
                // this is the one path that actually needs the false-until-proven state.
                .emailVerified(false)
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

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            logger.warn("Login failed: email not verified {}", request.getEmail());
            throw new EmailNotVerifiedException("Please verify your email before signing in");
        }

        logger.info("User logged in: {}", request.getEmail());
        return jwtProvider.generateToken(user.getEmail());
    }

    @Transactional
    public String verifyEmail(String email, String code) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            // Already verified (e.g. a stale/reused tab) - completing login again here, rather
            // than erroring, is harmless and matches what the user is actually trying to do.
            return jwtProvider.generateToken(email);
        }
        validateVerificationCode(user, code);

        user.setEmailVerified(true);
        user.setVerificationCode(null);
        user.setVerificationCodeExpiresAt(null);
        userRepository.save(user);

        logger.info("Email verified for: {}", email);
        return jwtProvider.generateToken(email);
    }

    @Transactional
    public void resendVerificationCode(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new IllegalArgumentException("This account is already verified");
        }

        Instant last = lastResendAt.get(email);
        if (last != null && last.plusSeconds(RESEND_COOLDOWN_SECONDS).isAfter(Instant.now())) {
            throw new IllegalArgumentException("Please wait a moment before requesting another code");
        }

        issueAndSendVerificationCode(user, user.getEmail());
        lastResendAt.put(email, Instant.now());
        logger.info("Verification code resent to: {}", email);
    }

    /**
     * Starts an email change for the signed-in user at [currentEmail]: verifies
     * [currentPassword] (a hijacked session must not be able to silently take over the
     * account's identity), rejects a no-op or already-taken [newEmail], then sends an OTP to
     * [newEmail] - the change only takes effect once {@link #confirmEmailChange} succeeds.
     */
    @Transactional
    public void requestEmailChange(String currentEmail, String currentPassword, String newEmail) {
        User user = userRepository.findByEmail(currentEmail)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            logger.warn("Email change request failed: incorrect password for {}", currentEmail);
            throw new BadCredentialsException("Incorrect password");
        }
        if (newEmail.equalsIgnoreCase(currentEmail)) {
            throw new IllegalArgumentException("New email must be different from your current one");
        }
        if (userRepository.existsByEmailIgnoreCase(newEmail)) {
            throw new IllegalArgumentException("Email already in use");
        }

        user.setPendingEmail(newEmail);
        issueAndSendVerificationCode(user, newEmail);
        logger.info("Email change requested for {}: pending {}", currentEmail, newEmail);
    }

    /**
     * Completes an email change started by {@link #requestEmailChange}: on success, [User]'s
     * {@code email} becomes the previously-pending address, and - since the JWT subject is the
     * email itself (see {@code JwtProvider}) - a fresh token is returned for the caller to swap
     * in, the same way {@link #verifyEmail} already does for the registration flow.
     */
    @Transactional
    public String confirmEmailChange(String currentEmail, String code) {
        User user = userRepository.findByEmail(currentEmail)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        String pendingEmail = user.getPendingEmail();
        if (pendingEmail == null) {
            throw new IllegalArgumentException("No pending email change");
        }
        validateVerificationCode(user, code);
        // Re-checked here too: closes the race where a second account targeted the same new
        // address after this one's request but confirms first.
        if (userRepository.existsByEmailIgnoreCase(pendingEmail)) {
            throw new IllegalArgumentException("Email already in use");
        }

        user.setEmail(pendingEmail);
        user.setPendingEmail(null);
        user.setVerificationCode(null);
        user.setVerificationCodeExpiresAt(null);
        userRepository.save(user);

        try {
            emailService.sendEmailChangedNotice(currentEmail, pendingEmail);
        } catch (Exception e) {
            // Best-effort - the email change itself already succeeded and committed above, so
            // a failed notice-send must never undo it.
            logger.warn("Failed to send email-changed notice to {}: {}", currentEmail, e.getMessage());
        }

        logger.info("Email changed from {} to {}", currentEmail, pendingEmail);
        return jwtProvider.generateToken(pendingEmail);
    }

    @Transactional
    public void resendEmailChangeCode(String currentEmail) {
        User user = userRepository.findByEmail(currentEmail)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
        if (user.getPendingEmail() == null) {
            throw new IllegalArgumentException("No pending email change");
        }

        Instant last = lastResendAt.get(currentEmail);
        if (last != null && last.plusSeconds(RESEND_COOLDOWN_SECONDS).isAfter(Instant.now())) {
            throw new IllegalArgumentException("Please wait a moment before requesting another code");
        }

        issueAndSendVerificationCode(user, user.getPendingEmail());
        lastResendAt.put(currentEmail, Instant.now());
        logger.info("Email change code resent for: {}", currentEmail);
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
                            // Google already verified this address - no OTP step needed here.
                            .emailVerified(true)
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();
                    return userRepository.save(newUser);
                });

        logger.info("Google login successful for: {}", email);
        return jwtProvider.generateToken(user.getEmail());
    }
}
