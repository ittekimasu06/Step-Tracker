package com.steptrack.service;

import com.steptrack.dto.HourlyStepEntryRequest;
import com.steptrack.dto.HourlyStepEntryResponse;
import com.steptrack.dto.HourlyStepsListResponse;
import com.steptrack.dto.HourlyStepsUpdateRequest;
import com.steptrack.dto.StepEntryRequest;
import com.steptrack.dto.StepEntryResponse;
import com.steptrack.model.DailySteps;
import com.steptrack.model.HourlySteps;
import com.steptrack.model.User;
import com.steptrack.repository.DailyStepsRepository;
import com.steptrack.repository.HourlyStepsRepository;
import com.steptrack.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StepService {

    private static final Logger logger = LoggerFactory.getLogger(StepService.class);

    private final DailyStepsRepository dailyStepsRepository;
    private final HourlyStepsRepository hourlyStepsRepository;
    private final UserRepository userRepository;

    @Transactional(readOnly = true)
    public StepEntryResponse getSteps(String email, String dateStr) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        LocalDate date = parseDate(dateStr);
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        DailySteps entry = dailyStepsRepository.findByUserIdAndStepDate(user.getId(), date)
                .orElseGet(() -> {
                    logger.debug("No step entry for user {} on {}, returning default", email, date);
                    return DailySteps.builder()
                            .userId(user.getId())
                            .stepDate(date)
                            .stepCount(0)
                            .activeMinutes(0)
                            .build();
                });

        return mapToResponse(entry);
    }

    @Transactional
    public StepEntryResponse saveSteps(String email, String dateStr, StepEntryRequest request) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        LocalDate date = parseDate(dateStr);
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        DailySteps entry = dailyStepsRepository.findByUserIdAndStepDate(user.getId(), date)
                .orElse(DailySteps.builder()
                        .userId(user.getId())
                        .stepDate(date)
                        .build());

        entry.setStepCount(request.getStepCount());
        entry.setActiveMinutes(request.getActiveMinutes());
        DailySteps saved = dailyStepsRepository.save(entry);

        logger.info("Steps updated for user {} on {}: {}", email, date, request.getStepCount());
        return mapToResponse(saved);
    }

    @Transactional(readOnly = true)
    public HourlyStepsListResponse getHourlySteps(String email, String dateStr) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        LocalDate date = parseDate(dateStr);
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        List<HourlyStepEntryResponse> hours = hourlyStepsRepository
                .findByUserIdAndStepDateOrderByHourOfDay(user.getId(), date)
                .stream()
                .map(this::mapHourlyToResponse)
                .toList();

        return HourlyStepsListResponse.builder().hours(hours).build();
    }

    @Transactional
    public HourlyStepsListResponse saveHourlySteps(String email, String dateStr, HourlyStepsUpdateRequest request) {
        if (email == null || email.isEmpty()) {
            throw new IllegalArgumentException("Email cannot be empty");
        }

        LocalDate date = parseDate(dateStr);
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        List<HourlyStepEntryResponse> results = request.getHours().stream()
                .map(entry -> saveHourlyEntry(user.getId(), date, entry))
                .toList();

        logger.info("Hourly steps updated for user {} on {}: {} hour(s)", email, date, results.size());
        return HourlyStepsListResponse.builder().hours(results).build();
    }

    private HourlyStepEntryResponse saveHourlyEntry(UUID userId, LocalDate date, HourlyStepEntryRequest entry) {
        HourlySteps row = hourlyStepsRepository
                .findByUserIdAndStepDateAndHourOfDay(userId, date, entry.getHourOfDay())
                .orElse(HourlySteps.builder()
                        .userId(userId)
                        .stepDate(date)
                        .hourOfDay(entry.getHourOfDay())
                        .build());

        row.setStepCount(entry.getStepCount());
        row.setActiveMinutes(entry.getActiveMinutes());
        return mapHourlyToResponse(hourlyStepsRepository.save(row));
    }

    /** Once daily, deletes hourly detail older than the trailing 7-day retention window (today
     * back 6 days) - the daily totals in {@link DailySteps} are unaffected and kept forever. */
    @Scheduled(cron = "0 0 3 * * *")
    @Transactional
    public void purgeOldHourlyData() {
        LocalDate cutoff = LocalDate.now().minusDays(6);
        hourlyStepsRepository.deleteByStepDateBefore(cutoff);
        logger.info("Purged hourly_steps rows older than {}", cutoff);
    }

    private LocalDate parseDate(String dateStr) {
        try {
            return LocalDate.parse(dateStr);
        } catch (DateTimeParseException e) {
            throw new IllegalArgumentException("Invalid date format, expected YYYY-MM-DD");
        }
    }

    private StepEntryResponse mapToResponse(DailySteps entry) {
        return StepEntryResponse.builder()
                .date(entry.getStepDate())
                .stepCount(entry.getStepCount())
                .activeMinutes(entry.getActiveMinutes())
                .updatedAt(entry.getUpdatedAt())
                .build();
    }

    private HourlyStepEntryResponse mapHourlyToResponse(HourlySteps entry) {
        return HourlyStepEntryResponse.builder()
                .hourOfDay(entry.getHourOfDay())
                .stepCount(entry.getStepCount())
                .activeMinutes(entry.getActiveMinutes())
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
