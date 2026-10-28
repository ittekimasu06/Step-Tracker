package com.steptrack.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * True once the account's owner has proven they control {@link #email} - via an OTP code
     * (email/password registration, see {@code AuthService.verifyEmail}) or implicitly (Google
     * sign-in, which already verified the email on Google's side). Defaults true so any
     * builder call site that doesn't set it explicitly (none should, going forward) fails
     * open rather than locking an account out - the real false-by-default behavior for new
     * email/password registrations is set explicitly in {@code AuthService.register}.
     */
    @Builder.Default
    @Column(name = "email_verified", nullable = false)
    private Boolean emailVerified = true;

    /** Null except during the window between registering and verifying. */
    @Column(name = "verification_code", length = 6)
    private String verificationCode;

    @Column(name = "verification_code_expires_at")
    private LocalDateTime verificationCodeExpiresAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
