import 'api_client.dart';

/// Connect tab's progress-sharing posts - mirrors [FriendService]'s exact pattern (singleton,
/// raw `Map<String, dynamic>` responses, named-key list unwrapping, `ApiException` left to
/// propagate for callers to catch).
class PostService {
  static PostService? _instance;
  static PostService get instance => _instance ??= PostService._();
  PostService._();

  final _api = ApiClient.instance;

  /// Shares today's current steps/active minutes/calories (and today's goals) as a frozen
  /// snapshot - [calorieCount] is the one value the backend can't derive itself (see
  /// `PostCreateRequest`'s doc on the backend), so it's passed from here using the exact same
  /// number already live on the dashboard at share time.
  Future<Map<String, dynamic>> createPost({required int calorieCount}) async {
    return _api.post('/posts', data: {'calorieCount': calorieCount});
  }

  Future<List<Map<String, dynamic>>> getFeed({int page = 0}) async {
    final data = await _api.get('/posts/feed?page=$page');
    return List<Map<String, dynamic>>.from(data['posts'] as List? ?? const []);
  }

  Future<void> likePost(String postId) async {
    await _api.post('/posts/$postId/like');
  }

  Future<void> unlikePost(String postId) async {
    await _api.delete('/posts/$postId/like');
  }
}
