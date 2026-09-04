import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown for any failed request, with a message safe to show to the user.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Talks to the Spring Boot backend and stores the JWT it issues.
///
/// The base URL defaults per platform: 10.0.2.2 is the Android emulator's alias
/// for the host machine's localhost, which plain "localhost" does not reach from
/// inside the emulator. Override with --dart-define=API_BASE_URL=... for a real
/// device, a different port, or a deployed backend.
class ApiClient {
  ApiClient._() {
    final baseUrl = _configuredBaseUrl.isNotEmpty
        ? _configuredBaseUrl
        : _defaultBaseUrlForPlatform();

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // A caller can pin a request to a specific token (see [get]/[put]'s
          // `token` parameter) rather than whatever is currently signed in -
          // don't clobber that with the ambient one.
          if (!options.headers.containsKey('Authorization')) {
            final token = await getToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            clearToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  static const String _tokenKey = 'auth_token';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
  );

  static String _defaultBaseUrlForPlatform() {
    if (kIsWeb) return 'http://localhost:8080/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api';
    }
    return 'http://localhost:8080/api';
  }

  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  /// Invoked whenever a request comes back 401, so listeners (AuthProvider) can
  /// drop their in-memory auth state to match the now-cleared stored token.
  void Function()? onUnauthorized;

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  /// [token], if given, pins this request to that exact token instead of
  /// whatever is currently signed in - see [StepTracker] for why that
  /// matters: a request built from data collected under one account must
  /// never be sent under a different account's session.
  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _send(
      () => _dio.get<Map<String, dynamic>>(path, options: _optionsFor(token)),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> post(String path, {Object? data, String? token}) async {
    final response = await _send(
      () => _dio.post<Map<String, dynamic>>(path, data: data, options: _optionsFor(token)),
    );
    return response.data ?? const {};
  }

  Future<Map<String, dynamic>> put(String path, {Object? data, String? token}) async {
    final response = await _send(
      () => _dio.put<Map<String, dynamic>>(path, data: data, options: _optionsFor(token)),
    );
    return response.data ?? const {};
  }

  Options? _optionsFor(String? token) {
    if (token == null) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> delete(String path) async {
    await _send(() => _dio.delete<void>(path));
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException(_messageFor(e), statusCode: e.response?.statusCode);
    }
  }

  String _messageFor(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Check your network and try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your network and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
