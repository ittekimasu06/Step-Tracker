import 'api_client.dart';

class ConsultantService {
  static ConsultantService? _instance;
  static ConsultantService get instance => _instance ??= ConsultantService._();
  ConsultantService._();

  final _api = ApiClient.instance;

  /// Requests a one-shot advice summary based on the signed-in user's real
  /// profile and recent step history. Unlike most services here, this
  /// rethrows [ApiException] instead of returning null on failure - the
  /// cooldown case (calling again too soon) carries a real, user-relevant
  /// message worth showing as-is, not collapsing into a generic error.
  Future<String> getAdvice() async {
    final data = await _api.post('/consultant/advice');
    return data['advice'] as String? ?? '';
  }
}
