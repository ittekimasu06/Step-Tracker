import 'api_client.dart';

class FriendService {
  static FriendService? _instance;
  static FriendService get instance => _instance ??= FriendService._();
  FriendService._();

  final _api = ApiClient.instance;

  /// Searches other users by full name. Rethrows [ApiException] (e.g. the
  /// server's "at least 3 characters" rejection) instead of swallowing it,
  /// since the caller (search UI) wants to show that message verbatim.
  Future<List<Map<String, dynamic>>> search(String query) async {
    final data = await _api.get('/friends/search?query=${Uri.encodeQueryComponent(query)}');
    return List<Map<String, dynamic>>.from(data['results'] as List? ?? const []);
  }

  Future<void> sendRequest(String targetUserId) async {
    await _api.post('/friends/requests', data: {'targetUserId': targetUserId});
  }

  Future<List<Map<String, dynamic>>> getIncomingRequests() async {
    final data = await _api.get('/friends/requests');
    return List<Map<String, dynamic>>.from(data['requests'] as List? ?? const []);
  }

  Future<void> acceptRequest(String requestId) async {
    await _api.post('/friends/requests/$requestId/accept');
  }

  Future<void> declineRequest(String requestId) async {
    await _api.post('/friends/requests/$requestId/decline');
  }

  Future<List<Map<String, dynamic>>> getSentRequests() async {
    final data = await _api.get('/friends/requests/sent');
    return List<Map<String, dynamic>>.from(data['requests'] as List? ?? const []);
  }

  Future<void> cancelRequest(String requestId) async {
    await _api.delete('/friends/requests/$requestId');
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final data = await _api.get('/friends');
    return List<Map<String, dynamic>>.from(data['friends'] as List? ?? const []);
  }

  Future<void> unfriend(String friendUserId) async {
    await _api.delete('/friends/$friendUserId');
  }

  /// [period] is one of 'day', 'week', 'month'.
  Future<List<Map<String, dynamic>>> getLeaderboard(String period) async {
    final data = await _api.get('/friends/leaderboard?period=$period');
    return List<Map<String, dynamic>>.from(data['entries'] as List? ?? const []);
  }
}
