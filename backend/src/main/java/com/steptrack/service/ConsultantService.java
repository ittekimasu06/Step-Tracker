package com.steptrack.service;

import com.steptrack.model.DailySteps;
import com.steptrack.model.User;
import com.steptrack.model.UserProfile;
import com.steptrack.repository.DailyStepsRepository;
import com.steptrack.repository.UserProfileRepository;
import com.steptrack.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Builds a one-shot fitness/wellness advice summary from a user's real profile and recent
 * step history, via {@link ConsultantAiClient}. Deliberately not wrapped in a single
 * {@code @Transactional} - the DB reads below are each their own short-lived transaction
 * (no lazy associations to keep open), so a connection isn't held from the pool for the
 * whole duration of the external Anthropic call.
 */
@Service
@RequiredArgsConstructor
public class ConsultantService {

    private static final Logger logger = LoggerFactory.getLogger(ConsultantService.class);
    private static final int HISTORY_DAYS = 14;
    private static final long COOLDOWN_SECONDS = 30;

    private static final String SYSTEM_PROMPT = """
            You are a supportive fitness and wellness companion inside a step-tracking app. \
            You give general encouragement and lifestyle suggestions based only on the \
            activity data provided below - you are not a doctor, you do not diagnose \
            conditions, and you do not prescribe treatment. If something in the data \
            suggests a real health concern, suggest the user talk to a real doctor rather \
            than offering a medical opinion yourself. Avoid specific numeric prescriptions \
            (exact calorie targets, target heart-rate zones) unless heavily hedged as a \
            general guideline, not a personalized plan. Profile fields marked "not \
            provided" are genuinely unknown - do not guess or assume a value for them. \
            This is a single, standalone request with no memory of past conversations - \
            do not refer to "last time" or imply you remember the user from before. Keep \
            the response to one or two short paragraphs, warm and encouraging in tone.""";

    private final UserRepository userRepository;
    private final UserProfileRepository userProfileRepository;
    private final DailyStepsRepository dailyStepsRepository;
    private final ConsultantAiClient consultantAiClient;

    private final Map<UUID, Instant> lastRequestAt = new ConcurrentHashMap<>();

    public String getAdvice(String email) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        Instant last = lastRequestAt.get(user.getId());
        if (last != null && last.plusSeconds(COOLDOWN_SECONDS).isAfter(Instant.now())) {
            throw new IllegalArgumentException("Please wait a moment before requesting advice again");
        }

        UserProfile profile = userProfileRepository.findById(user.getId())
                .orElseGet(() -> UserProfile.builder()
                        .id(user.getId())
                        .profileCompleted(false)
                        .build());

        List<DailySteps> history = dailyStepsRepository
                .findByUserIdAndStepDateGreaterThanEqualOrderByStepDateAsc(
                        user.getId(), LocalDate.now().minusDays(HISTORY_DAYS - 1L));

        String userPrompt = buildDataSummary(profile, history);
        String advice = consultantAiClient.getAdvice(SYSTEM_PROMPT, userPrompt);

        lastRequestAt.put(user.getId(), Instant.now());
        logger.info("Consultant advice generated for user: {}", email);
        return advice;
    }

    private String buildDataSummary(UserProfile profile, List<DailySteps> history) {
        StringBuilder sb = new StringBuilder();
        sb.append("User profile:\n");
        sb.append("- Age: ").append(orNotProvided(profile.getAge())).append('\n');
        sb.append("- Weight (kg): ").append(orNotProvided(profile.getWeightKg())).append('\n');
        sb.append("- Height (cm): ").append(orNotProvided(profile.getHeightCm())).append('\n');
        sb.append("- Gender: ").append(orNotProvided(profile.getGender())).append('\n');
        sb.append("- Daily step goal: ").append(orNotProvided(profile.getStepGoal())).append('\n');
        sb.append("- Daily active-minutes goal: ").append(orNotProvided(profile.getActiveMinutesGoal())).append('\n');
        sb.append("- Daily calorie goal: ").append(orNotProvided(profile.getCalorieGoal())).append("\n\n");

        sb.append("Step/activity history for the last ").append(HISTORY_DAYS).append(" days:\n");
        if (history.isEmpty()) {
            sb.append("No step data has been recorded yet.\n");
        } else {
            DateTimeFormatter fmt = DateTimeFormatter.ISO_LOCAL_DATE;
            for (DailySteps day : history) {
                sb.append("- ").append(day.getStepDate().format(fmt))
                        .append(": ").append(day.getStepCount()).append(" steps, ")
                        .append(day.getActiveMinutes()).append(" active minutes\n");
            }
        }

        sb.append("\nBased on this data, give the user some brief, encouraging fitness and wellness advice.");
        return sb.toString();
    }

    private String orNotProvided(Object value) {
        return value == null ? "not provided" : value.toString();
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
