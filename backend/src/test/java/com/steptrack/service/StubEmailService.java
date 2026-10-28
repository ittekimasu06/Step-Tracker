package com.steptrack.service;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Replaces {@link SesEmailService} under the {@code test} profile so integration tests never
 * send a real email - mirrors {@code StubConsultantAiClient}'s doc/shape. Records the last
 * code sent per address so tests can read it back and drive the real verify endpoint, rather
 * than needing to inspect a real inbox.
 */
@Service
@Profile("test")
public class StubEmailService implements EmailService {

    private static final Map<String, String> lastCodeByEmail = new ConcurrentHashMap<>();

    public static String lastCodeFor(String email) {
        return lastCodeByEmail.get(email);
    }

    @Override
    public void sendVerificationCode(String toEmail, String code) {
        lastCodeByEmail.put(toEmail, code);
    }
}
