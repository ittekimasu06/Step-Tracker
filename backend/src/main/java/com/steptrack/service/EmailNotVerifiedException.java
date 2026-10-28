package com.steptrack.service;

/**
 * Thrown by {@link AuthService#login} when the password matched but the account's email has
 * never been verified - distinct from {@code BadCredentialsException} (wrong email/password)
 * so {@code AuthController} can tell the two apart and route the client to the verification
 * screen instead of showing a generic "invalid credentials" error.
 */
public class EmailNotVerifiedException extends RuntimeException {
    public EmailNotVerifiedException(String message) {
        super(message);
    }
}
