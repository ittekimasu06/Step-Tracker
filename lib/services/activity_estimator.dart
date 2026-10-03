/// Default goals shown until a user sets their own, and the cadence threshold
/// for what counts as an "active" minute. See [ProfileService]/`UserProfile`
/// for how a user's own goals override these.
const int kDefaultStepGoal = 6000;
const int kDefaultActiveMinutesGoal = 90;
const int kDefaultCalorieGoal = 500;

/// A moment counts as "active" if the steps taken in the trailing
/// [kActiveWindowSeconds] cross this cadence - i.e. this represents a
/// **60 steps/min** cadence bar, evaluated as a sliding window (see
/// [StepTracker]) rather than a fixed clock-aligned minute. Originally 100
/// steps/min (the commonly-cited Tudor-Locke threshold for
/// moderate-intensity walking), but on-device testing showed that's
/// unrealistic as an all-or-nothing gate for a full window: even a brisk,
/// mostly-continuous walk (measured ~104 steps/min at its best stretch)
/// rarely sustains it without a brief pause (crossing a doorway, checking a
/// phone) dropping the whole window to zero - there's no partial credit
/// under fixed buckets. 60 steps/min comfortably credits normal walking with
/// minor pauses while still filtering out standing/fidgeting.
///
/// This is a threshold **per [kActiveWindowSeconds]**, not a fixed absolute
/// count - keep it proportional to the window width if that ever changes
/// (see [kActiveWindowSeconds]'s own doc for the 60s->20s->10s->30s history
/// and why this threshold has always shrunk/grown in lockstep to preserve
/// the same 60 steps/min cadence bar rather than becoming a stricter or
/// looser one).
const int kActiveMinuteStepThreshold = 15;

/// The width of the trailing window [StepTracker] evaluates cadence over.
///
/// Originally 60s, which meant a genuinely continuous walk had to sustain
/// [kActiveMinuteStepThreshold] steps for a full 60 seconds *before the
/// window had even filled up once* - confirmed via on-device log
/// instrumentation that this "cold start" alone took ~37 seconds of
/// real, uninterrupted walking before the very first moment counted as
/// active, crediting zero for that entire warm-up regardless of how long the
/// walk continued afterward. Real daily walking is mostly short bursts
/// (a few steps to another room, etc.) that never sustain 37 seconds
/// continuously, so under the 60s window most ordinary walking was credited
/// nothing at all, not just "a bit less than expected" - confirmed against
/// Samsung Health crediting 2 active minutes for a day this app credited 0.
/// Shortened to 20s (with [kActiveMinuteStepThreshold] scaled down to 20 in
/// lockstep, keeping the same 60 steps/min cadence bar), which dropped the
/// cold-start to ~12-13s and was confirmed on-device to credit noticeably
/// faster on short walking bursts.
///
/// Tried at 10s next (threshold scaled to 10) to push the cold-start down
/// further, but this backfired: on-device log capture on this exact phone
/// (during the 20s-window test) already showed the sensor's own event
/// delivery has periodic gaps of 5-17 seconds *even during continuous real
/// walking* - likely OS-level sensor batching/power-saving, not the user
/// pausing. A 20s window comfortably bridges a 17s gap (17 < 20), but a 10s
/// window does not (17 > 10) - older samples aged out completely before the
/// next batch of events arrived, so the window's step-sum kept resetting
/// near zero and essentially never reached threshold. Confirmed by the user
/// reporting zero credited active time after 3 minutes of continuous real
/// walking under the 10s window - not a logic bug, the window was simply
/// shorter than this device's own natural sensor-delivery gaps.
///
/// Settled at 30s (threshold scaled to 15) - comfortably bridges the
/// observed 5-17s sensor-delivery gaps with margin, while still cutting the
/// cold-start roughly in half versus 20s (~6-7s at normal cadence instead of
/// ~12-13s). Confirmed on-device across multiple real walks as stable - no
/// flickering on/off during continuous walking, no false triggers from
/// incidental movement. If a future change to this value causes flickering
/// or undercounting, the sensor's own delivery gaps (not the threshold math)
/// are the likely cause - check with the same kind of on-device timestamp
/// logging used to diagnose the 10s regression rather than guessing at
/// another number.
const int kActiveWindowSeconds = 30;

/// How many trailing days (including today) the backend keeps hourly step/
/// active-minute detail for - older `hourly_steps` rows are purged daily
/// (see `StepService.purgeOldHourlyData` on the backend). Matches the
/// weekly strip's own trailing window, so "how far back is hourly detail
/// available" and "how far back does the week strip go" are the same
/// number. If either side's window changes, keep this in sync with the
/// backend's `LocalDate.now().minusDays(6)` cutoff.
const int kHourlyRetentionDays = 7;

/// Pure, stateless calorie/distance estimates derived from step count and
/// (optionally) the user's profile weight/height. These are standard
/// order-of-magnitude fitness-app approximations, not medical-grade - they
/// exist to make the dashboard show a real, sane number instead of a mock
/// one, not to be clinically accurate.
class ActivityEstimator {
  static const double _defaultHeightCm = 170;
  static const double _defaultWeightKg = 68;
  static const int _defaultAge = 30;

  /// Stride length as ~41.5% of height - a commonly-cited approximation.
  static double strideLengthMeters(double? heightCm) =>
      (heightCm ?? _defaultHeightCm) * 0.415 / 100;

  static double distanceKm(int steps, double? heightCm) =>
      steps * strideLengthMeters(heightCm) / 1000;

  /// MET (metabolic equivalent) for an approximate walking speed, from the
  /// standard `calories = MET x weight(kg) x hours` formula (1 MET = 1
  /// kcal/kg/hour by definition). Bands are exact km/h conversions of a
  /// commonly-cited mph/MET table (2.0/3.0/3.5/4.0 mph -> 3.0/3.5/4.3/5.0
  /// MET); the base 2.8 MET below 3.2 km/h matches standard compendium
  /// values for a slow/leisurely walk.
  static double _metForSpeedKmh(double speedKmh) {
    if (speedKmh < 3.2) return 2.8;
    if (speedKmh < 4.8) return 3.0;
    if (speedKmh < 5.6) return 3.5;
    if (speedKmh < 6.4) return 4.3;
    return 5.0;
  }

  /// Activity calories (extra burn from walking, on top of resting
  /// metabolism - see [bmr]) via MET, replacing a flat per-step constant
  /// with one that varies by how fast the walking actually was - derived
  /// entirely from data already tracked (steps, active minutes, profile
  /// height/weight), no GPS or extra sensors needed.
  ///
  /// Speed is approximated from cadence = steps / activeMinutes - steps per
  /// minute of *credited, sustained* walking (see [StepTracker]'s
  /// active-minute cadence threshold), not total daily steps - converted to
  /// km/h via [strideLengthMeters]. Call this per-hour and sum, not once on
  /// a whole day's totals: mixing a day's scattered/incidental steps into
  /// the cadence for one unrelated sustained bout can imply a nonsensical
  /// pace for that bout. Steps outside any credited bout end up contributing
  /// ~0 extra activity-calorie credit either way - not because resting
  /// metabolism already covers them (it doesn't, by definition), but because
  /// there's no reliable way to price isolated/incidental movement without
  /// per-step timing data this app doesn't persist; their real contribution
  /// is typically small, so approximating it as zero is a pragmatic
  /// engineering call, not a clinical claim.
  ///
  /// Returns 0 if [activeMinutes] is 0 - there's no sustained bout to derive
  /// a pace from (and it avoids a division by zero). Speed is clamped to a
  /// sane walking range before the MET lookup, as a backstop against an
  /// implausible pace from a rounding/sync-boundary edge case.
  static double activityCalories({
    required int steps,
    required int activeMinutes,
    double? weightKg,
    double? heightCm,
  }) {
    if (activeMinutes <= 0) return 0;
    final cadence = steps / activeMinutes;
    final speedKmh = (cadence * strideLengthMeters(heightCm) * 60 / 1000)
        .clamp(2.0, 8.0);
    final met = _metForSpeedKmh(speedKmh);
    return met * (weightKg ?? _defaultWeightKg) * (activeMinutes / 60);
  }

  /// Full-day resting/basal calorie burn (Mifflin-St Jeor equation) - what
  /// the body burns just to function (heartbeat, breathing, body heat) with
  /// zero activity, over a full 24h. This is what most fitness apps' "total
  /// calories burned" actually mostly consists of - [calories] above is only
  /// the *extra* burn from walking, which is typically a small fraction of
  /// this number.
  ///
  /// `gender` follows this app's own profile options ('Male'/'Female'/
  /// 'Non-binary'/'Prefer not to say') - only 'Male' and 'Female' have a
  /// biologically-distinct offset in the equation, so anything else
  /// (including unset) uses the average of the two offsets rather than
  /// silently defaulting to one or the other.
  static double bmr({double? weightKg, double? heightCm, int? age, String? gender}) {
    final base = 10 * (weightKg ?? _defaultWeightKg) +
        6.25 * (heightCm ?? _defaultHeightCm) -
        5 * (age ?? _defaultAge);
    switch (gender) {
      case 'Male':
        return base + 5;
      case 'Female':
        return base - 161;
      default:
        return base - 78; // average of the male (+5) and female (-161) offsets
    }
  }

  /// How much of a full day's [bmr] to count as "burned so far": pass 1.0
  /// for any day that's already fully over (all 24h of resting burn already
  /// happened, however long ago it's being looked at now), or
  /// [elapsedDayFraction] of [now] for the day currently in progress, so the
  /// resting total only reflects the day so far rather than calories that
  /// haven't been burned yet.
  static double restingCalories(double fullDayBmr, double elapsedDayFraction) =>
      fullDayBmr * elapsedDayFraction.clamp(0.0, 1.0);

  /// Elapsed fraction of the calendar day [now] falls on: 0.0 at midnight,
  /// approaching 1.0 just before the next midnight. Takes [now] as a
  /// parameter rather than reading `DateTime.now()` internally, keeping this
  /// class pure/stateless and testable like its other methods.
  static double elapsedDayFraction(DateTime now) =>
      (now.hour * 3600 + now.minute * 60 + now.second) / 86400;

  /// Sums [activityCalories] per-hour across every hour present in either
  /// map, rather than calling it once on whole-day totals - mixing a day's
  /// scattered/incidental steps into the cadence for one unrelated sustained
  /// bout can imply a nonsensical pace for that bout (see [activityCalories]'s
  /// doc). Shared by the dashboard's calorie display and the background
  /// service's goal-threshold checks (see [GoalNotificationsService]), so
  /// both always agree on exactly the same "calories so far today" number.
  static int sumHourlyActivityCalories(
    Map<int, int> steps,
    Map<int, int> activeMinutes, {
    double? weightKg,
    double? heightCm,
  }) {
    var total = 0.0;
    final hours = <int>{...steps.keys, ...activeMinutes.keys};
    for (final h in hours) {
      total += activityCalories(
        steps: steps[h] ?? 0,
        activeMinutes: activeMinutes[h] ?? 0,
        weightKg: weightKg,
        heightCm: heightCm,
      );
    }
    return total.round();
  }
}
