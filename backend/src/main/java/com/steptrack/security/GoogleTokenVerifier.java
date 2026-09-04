package com.steptrack.security;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.List;

/**
 * Verifies Google ID tokens issued to this app's OAuth clients.
 *
 * <p>A Flutter app receives a token whose {@code aud} claim is the client ID of the
 * platform it signed in from (Android, iOS and Web each have their own), so every
 * client ID the app ships with must be listed in {@code app.google.client-ids}.
 */
@Component
public class GoogleTokenVerifier {

    private static final Logger logger = LoggerFactory.getLogger(GoogleTokenVerifier.class);

    @Value("${app.google.client-ids:}")
    private String clientIdsProperty;

    private GoogleIdTokenVerifier verifier;

    @PostConstruct
    void init() {
        List<String> audiences = Arrays.stream(clientIdsProperty.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();

        if (audiences.isEmpty()) {
            logger.warn("app.google.client-ids is not set - Google sign-in will be rejected until it is configured");
            return;
        }

        verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                .setAudience(audiences)
                .build();
        logger.info("Google ID token verification enabled for {} client ID(s)", audiences.size());
    }

    /**
     * Verifies a Google ID token and returns the verified email address.
     *
     * @param idToken the ID token supplied by the client
     * @return the verified email address
     * @throws IllegalArgumentException if the token is missing, invalid, or carries no verified email
     * @throws IllegalStateException    if Google sign-in has not been configured on this server
     */
    public String verifyAndExtractEmail(String idToken) {
        if (idToken == null || idToken.isBlank()) {
            throw new IllegalArgumentException("ID token cannot be empty");
        }
        if (verifier == null) {
            throw new IllegalStateException("Google sign-in is not configured on this server");
        }

        GoogleIdToken token;
        try {
            token = verifier.verify(idToken);
        } catch (GeneralSecurityException | IOException e) {
            logger.error("Could not verify Google ID token", e);
            throw new IllegalArgumentException("Could not verify Google ID token");
        }

        if (token == null) {
            throw new IllegalArgumentException("Invalid Google ID token");
        }

        GoogleIdToken.Payload payload = token.getPayload();
        String email = payload.getEmail();
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("Google ID token does not contain an email");
        }
        if (!Boolean.TRUE.equals(payload.getEmailVerified())) {
            throw new IllegalArgumentException("Google account email is not verified");
        }

        logger.debug("Verified Google token for {}", email);
        return email;
    }
}
