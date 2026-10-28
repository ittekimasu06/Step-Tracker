package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AuthResponse {

    private String token;
    private String email;
    private String message;

    /**
     * True on the register response (no token yet - see {@code AuthService.register}) and on
     * a login response rejected specifically for an unverified email ({@code
     * EmailNotVerifiedException}, HTTP 403) - one flag the Flutter client checks regardless of
     * which call produced it, to route to the verification screen.
     */
    @Builder.Default
    private boolean requiresVerification = false;
}
