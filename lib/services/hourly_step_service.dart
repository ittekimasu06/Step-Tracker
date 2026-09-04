import 'api_client.dart';

class HourlyStepEntry {
  final int hour;
  final int stepCount;
  final int activeMinutes;

  const HourlyStepEntry({
    required this.hour,
    required this.stepCount,
    required this.activeMinutes,
  });
}

class HourlyStepService {
  static HourlyStepService? _instance;
  static HourlyStepService get instance => _instance ??= HourlyStepService._();
  HourlyStepService._();

  final _api = ApiClient.instance;

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Fetches the hourly entries recorded for [date]. Returns null on failure
  /// (e.g. offline); a date with no hourly detail yet (including one outside
  /// the backend's retention window) returns an empty list, not null.
  ///
  /// [token], if given, pins this request to that exact account instead of
  /// whoever is currently signed in - see [StepTracker].
  Future<List<HourlyStepEntry>?> fetchHourlyEntries(
    DateTime date, {
    String? token,
  }) async {
    try {
      final data = await _api.get('/steps/${_formatDate(date)}/hours', token: token);
      final hours = data['hours'] as List<dynamic>? ?? const [];
      return hours
          .map(
            (e) => HourlyStepEntry(
              hour: e['hourOfDay'] as int,
              stepCount: e['stepCount'] as int? ?? 0,
              activeMinutes: e['activeMinutes'] as int? ?? 0,
            ),
          )
          .toList();
    } on ApiException {
      return null;
    }
  }

  /// Upserts every hour in [entries] for [date] in a single request. Returns
  /// whether it succeeded; a no-op (returns true) if [entries] is empty.
  ///
  /// [token], if given, pins this request to that exact account instead of
  /// whoever is currently signed in - see [StepTracker].
  Future<bool> syncHours(
    DateTime date,
    List<HourlyStepEntry> entries, {
    String? token,
  }) async {
    if (entries.isEmpty) return true;
    try {
      await _api.put(
        '/steps/${_formatDate(date)}/hours',
        data: {
          'hours': entries
              .map(
                (e) => {
                  'hourOfDay': e.hour,
                  'stepCount': e.stepCount,
                  'activeMinutes': e.activeMinutes,
                },
              )
              .toList(),
        },
        token: token,
      );
      return true;
    } on ApiException {
      return false;
    }
  }
}
