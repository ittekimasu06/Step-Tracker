/// Default goals shown until a user sets their own, and the cadence threshold
/// for what counts as an "active" minute. See [ProfileService]/`UserProfile`
/// for how a user's own goals override these.
const int kDefaultStepGoal = 6000;
const int kDefaultActiveMinutesGoal = 90;
const int kDefaultCalorieGoal = 500;

/// A moment counts as "active" if the steps taken in the trailing
/// [kActiveWindowSeconds] cross this cadence - i.e. this is still a
/// steps-per-minute threshold, just evaluated as a sliding window (see
/// [StepTracker]) rather than a fixed clock-aligned minute. Originally 100
/// steps/min (the commonly-cited Tudor-Locke threshold for
/// moderate-intensity walking), but on-device testing showed that's
/// unrealistic as an all-or-nothing gate for a full 60-second window: even a
/// brisk, mostly-continuous walk (measured ~104 steps/min at its best
/// stretch) rarely sustains it for an entire minute without a brief pause
/// (crossing a doorway, checking a phone) dropping the whole minute to zero -
/// there's no partial credit under fixed buckets. 60 comfortably credits
/// normal walking with minor pauses while still filtering out
/// standing/fidgeting.
const int kActiveMinuteStepThreshold = 60;

/// The width of the trailing window [StepTracker] evaluates cadence over.
const int kActiveWindowSeconds = 60;

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

  /// Stride length as ~41.5% of height - a commonly-cited approximation.
  static double strideLengthMeters(double? heightCm) =>
      (heightCm ?? _defaultHeightCm) * 0.415 / 100;

  static double distanceKm(int steps, double? heightCm) =>
      steps * strideLengthMeters(heightCm) / 1000;

  /// ~0.04 kcal/step for a ~68kg adult, linearly scaled by weight.
  static double caloriesPerStep(double? weightKg) =>
      0.04 * ((weightKg ?? _defaultWeightKg) / 68);

  static double calories(int steps, double? weightKg) =>
      steps * caloriesPerStep(weightKg);
}
