package com.steptrack.controller;

import com.steptrack.dto.FriendRequestCreate;
import com.steptrack.service.FriendshipService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;

/**
 * The first controller in this codebase whose endpoints can return data belonging to a
 * user other than the caller (a friend's today step count/active minutes) - see
 * {@code FriendshipService}'s doc for how that boundary is enforced. Error responses use
 * {@code ResponseEntity<?>} + a real {@code message} body (the {@code ConsultantController}
 * precedent), not the usual bare {@code .build()}, since this feature has several distinct
 * user-facing validation states ("already friends", "request already sent", etc.) worth
 * showing verbatim rather than a generic failure message.
 */
@RestController
@RequestMapping("/friends")
@RequiredArgsConstructor
public class FriendController {

    private static final Logger logger = LoggerFactory.getLogger(FriendController.class);

    private final FriendshipService friendshipService;

    @GetMapping("/search")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> search(@RequestParam String query) {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(friendshipService.search(email, query));
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error searching users", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/requests")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> sendRequest(@Valid @RequestBody FriendRequestCreate request) {
        try {
            String email = requireEmail();
            friendshipService.sendRequest(email, request.getTargetUserId());
            return ResponseEntity.status(HttpStatus.CREATED).build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error sending friend request", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/requests")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getIncomingRequests() {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(friendshipService.getIncomingRequests(email));
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error retrieving friend requests", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/requests/{id}/accept")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> acceptRequest(@PathVariable UUID id) {
        try {
            String email = requireEmail();
            friendshipService.acceptRequest(email, id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error accepting friend request", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/requests/{id}/decline")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> declineRequest(@PathVariable UUID id) {
        try {
            String email = requireEmail();
            friendshipService.declineRequest(email, id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error declining friend request", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/requests/sent")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getSentRequests() {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(friendshipService.getSentRequests(email));
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error retrieving sent friend requests", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/requests/{id}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> cancelSentRequest(@PathVariable UUID id) {
        try {
            String email = requireEmail();
            friendshipService.cancelSentRequest(email, id);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error cancelling friend request", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/leaderboard")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getLeaderboard(@RequestParam String period) {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(friendshipService.getLeaderboard(email, period));
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error retrieving leaderboard", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getFriends() {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(friendshipService.getFriends(email));
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error retrieving friends", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{friendUserId}")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> unfriend(@PathVariable UUID friendUserId) {
        try {
            String email = requireEmail();
            friendshipService.unfriend(email, friendUserId);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error removing friend", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    private String requireEmail() {
        String email = friendshipService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            throw new UnauthorizedException();
        }
        return email;
    }

    private ResponseEntity<?> badRequest(IllegalArgumentException e) {
        logger.warn("Invalid friend request operation: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
    }

    private ResponseEntity<?> unauthorized() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }

    /** Internal signal only - never leaves this controller, see {@link #unauthorized()}. */
    private static class UnauthorizedException extends RuntimeException {
    }
}
