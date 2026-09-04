package com.steptrack.service;

import com.steptrack.dto.UserProfileRequest;
import com.steptrack.dto.UserProfileResponse;
import com.steptrack.model.User;
import com.steptrack.model.UserProfile;
import com.steptrack.repository.DailyStepsRepository;
import com.steptrack.repository.HourlyStepsRepository;
import com.steptrack.repository.UserProfileRepository;
import com.steptrack.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
public class ProfileService {

    private static final Logger logger = LoggerFactory.getLogger(ProfileService.class);

    private final UserProfileRepository userProfileRepository;
    private final UserRepository userRepository;
    private final DailyStepsRepository dailyStepsRepository;
    private final HourlyStepsRepository hourlyStepsRepository;

    @Transactional(readOnly = true)
    public UserProfileResponse getProfile(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        UserProfile profile = userProfileRepository.findById(user.getId())
                .orElseGet(() -> {
                    logger.debug("Profile not found for user {}, returning default", email);
                    return UserProfile.builder()
                            .id(user.getId())
                            .profileCompleted(false)
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();
                });

        return mapToResponse(profile, user.getEmail());
    }

    @Transactional
    public UserProfileResponse saveProfile(String email, UserProfileRequest request) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        UserProfile profile = userProfileRepository.findById(user.getId())
                .orElse(UserProfile.builder()
                        .id(user.getId())
                        .createdAt(LocalDateTime.now())
                        .build());

        // Update profile fields
        if (request.getFullName() != null && !request.getFullName().isEmpty()) {
            profile.setFullName(request.getFullName());
        }
        if (request.getAge() != null) {
            profile.setAge(request.getAge());
        }
        if (request.getWeightKg() != null) {
            profile.setWeightKg(request.getWeightKg());
        }
        if (request.getHeightCm() != null) {
            profile.setHeightCm(request.getHeightCm());
        }
        if (request.getGender() != null && !request.getGender().isEmpty()) {
            profile.setGender(request.getGender());
        }
        if (request.getProfileCompleted() != null) {
            profile.setProfileCompleted(request.getProfileCompleted());
        }
        if (request.getStepGoal() != null) {
            profile.setStepGoal(request.getStepGoal());
        }
        if (request.getActiveMinutesGoal() != null) {
            profile.setActiveMinutesGoal(request.getActiveMinutesGoal());
        }
        if (request.getCalorieGoal() != null) {
            profile.setCalorieGoal(request.getCalorieGoal());
        }

        profile.setUpdatedAt(LocalDateTime.now());
        UserProfile savedProfile = userProfileRepository.save(profile);
        
        logger.info("Profile updated for user: {}", email);
        return mapToResponse(savedProfile, email);
    }

    /** Permanently deletes the signed-in user's profile and account. */
    @Transactional
    public void deleteAccount(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        hourlyStepsRepository.deleteByUserId(user.getId());
        dailyStepsRepository.deleteByUserId(user.getId());
        userProfileRepository.deleteById(user.getId());
        userRepository.delete(user);
        logger.info("Account deleted for user: {}", email);
    }

    private UserProfileResponse mapToResponse(UserProfile profile, String email) {
        return UserProfileResponse.builder()
                .id(profile.getId())
                .email(email)
                .fullName(profile.getFullName())
                .age(profile.getAge())
                .weightKg(profile.getWeightKg())
                .heightCm(profile.getHeightCm())
                .gender(profile.getGender())
                .profileCompleted(profile.getProfileCompleted())
                .stepGoal(profile.getStepGoal())
                .activeMinutesGoal(profile.getActiveMinutesGoal())
                .calorieGoal(profile.getCalorieGoal())
                .createdAt(profile.getCreatedAt())
                .updatedAt(profile.getUpdatedAt())
                .build();
    }

    /**
     * @return the signed-in user's email, or null if nobody is signed in. Anonymous
     *         authentication counts as signed out - {@code isAuthenticated()} is true for
     *         an {@link AnonymousAuthenticationToken}, whose name is "anonymousUser".
     */
    public String getCurrentUserEmail() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {
            return null;
        }
        return authentication.getName();
    }
}
