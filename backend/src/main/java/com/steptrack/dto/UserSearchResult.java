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
public class UserSearchResult {

    private UUID userId;
    private String fullName;

    /** One of NONE / PENDING_SENT / PENDING_RECEIVED / FRIENDS. */
    private String status;
}
