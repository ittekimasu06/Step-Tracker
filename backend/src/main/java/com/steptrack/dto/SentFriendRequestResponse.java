package com.steptrack.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SentFriendRequestResponse {

    private UUID id;
    private UUID toUserId;
    private String toFullName;
    private LocalDateTime createdAt;
}
