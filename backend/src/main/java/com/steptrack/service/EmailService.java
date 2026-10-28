package com.steptrack.service;

/**
 * Wraps whatever actually sends the verification-code email. Same reasoning as {@link
 * ConsultantAiClient} - a real, external side effect behind an interface so the test suite can
 * swap in a stub instead of emailing real addresses from {@code mvn verify}.
 */
public interface EmailService {
    void sendVerificationCode(String toEmail, String code);

    /** Best-effort notice sent to the OLD address once an email change completes. */
    void sendEmailChangedNotice(String toOldEmail, String newEmail);
}
