package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class LeaderboardEntry {

    private UUID userId;
    private String fullName;
    private String avatarId;
    private int steps;

    // Boxed Boolean, not primitive - a primitive `boolean isSelf` gets Lombok's
    // `isSelf()` getter, which Jackson strips the "is" prefix from and serializes
    // as JSON key "self", not "isSelf". Boxed Boolean gets `getIsSelf()`, which
    // Jackson correctly serializes as "isSelf" - same convention already used by
    // UserProfile.profileCompleted.
    private Boolean isSelf;
}
