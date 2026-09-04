import 'api_client.dart';

class DailyStepEntry {
  final int stepCount;
  final int activeMinutes;

  const DailyStepEntry({required this.stepCount, required this.activeMinutes});
}

class StepService {
  static StepService? _instance;
  static StepService get instance => _instance ??= StepService._();
  StepService._();

  final _api = ApiClient.instance;

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetch the step/active-minutes entry for [date]. Returns null on failure
  /// (e.g. offline); a day with no recorded entry yet still returns zeros,
  /// not null.
  ///
  /// [token], if given, pins this request to that exact account instead of
  /// whoever is currently signed in - see [StepTracker].
  Future<DailyStepEntry?> fetchDailyEntry(DateTime date, {String? token}) async {
    try {
      final data = await _api.get('/steps/${_formatDate(date)}', token: token);
      return DailyStepEntry(
        stepCount: data['stepCount'] as int? ?? 0,
        activeMinutes: data['activeMinutes'] as int? ?? 0,
      );
    } on ApiException {
      return null;
    }
  }

  /// Upserts the step count and active minutes for [date] together, as one
  /// row. Returns whether it succeeded.
  ///
  /// [token], if given, pins this request to that exact account instead of
  /// whoever is currently signed in - see [StepTracker].
  Future<bool> syncDailyEntry(
    DateTime date, {
    required int stepCount,
    required int activeMinutes,
    String? token,
  }) async {
    try {
      await _api.put(
        '/steps/${_formatDate(date)}',
        data: {'stepCount': stepCount, 'activeMinutes': activeMinutes},
        token: token,
      );
      return true;
    } on ApiException {
      return false;
    }
  }
}
