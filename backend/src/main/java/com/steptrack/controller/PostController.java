package com.steptrack.controller;

import com.steptrack.dto.PostCreateRequest;
import com.steptrack.service.PostService;
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

/** Same error-handling shape as {@link FriendController} - see its doc for why. */
@RestController
@RequestMapping("/posts")
@RequiredArgsConstructor
public class PostController {

    private static final Logger logger = LoggerFactory.getLogger(PostController.class);

    private final PostService postService;

    @PostMapping
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> createPost(@Valid @RequestBody PostCreateRequest request) {
        try {
            String email = requireEmail();
            return ResponseEntity.status(HttpStatus.CREATED)
                    .body(postService.createPost(email, request.getCalorieCount()));
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error creating post", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/feed")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> getFeed(@RequestParam(defaultValue = "0") int page) {
        try {
            String email = requireEmail();
            return ResponseEntity.ok(postService.getFeed(email, page));
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error retrieving feed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/{id}/like")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> like(@PathVariable UUID id) {
        try {
            String email = requireEmail();
            postService.like(email, id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error liking post", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/{id}/like")
    @PreAuthorize("hasRole('USER')")
    public ResponseEntity<?> unlike(@PathVariable UUID id) {
        try {
            String email = requireEmail();
            postService.unlike(email, id);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            return badRequest(e);
        } catch (UnauthorizedException e) {
            return unauthorized();
        } catch (Exception e) {
            logger.error("Error unliking post", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    private String requireEmail() {
        String email = postService.getCurrentUserEmail();
        if (email == null) {
            logger.warn("No authenticated user found");
            throw new UnauthorizedException();
        }
        return email;
    }

    private ResponseEntity<?> badRequest(IllegalArgumentException e) {
        logger.warn("Invalid post operation: {}", e.getMessage());
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("message", e.getMessage()));
    }

    private ResponseEntity<?> unauthorized() {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
    }

    private static class UnauthorizedException extends RuntimeException {
    }
}
