import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance => _instance ??= AuthService._();
  AuthService._();

  final _api = ApiClient.instance;
  bool _googleSignInInitialized = false;

  Future<bool> get isSignedIn async => await _api.getToken() != null;

  /// Reads the stored token, if any, and reports whether it looks usable
  /// (present and not past its expiry). This is a local, offline check only -
  /// it does not confirm the account still exists or the signature is intact;
  /// the first authenticated request that comes back 401 clears the token via
  /// [ApiClient.onUnauthorized].
  Future<bool> hasValidStoredSession() async {
    final token = await _api.getToken();
    if (token == null) return false;
    if (_isExpired(token)) {
      await _api.clearToken();
      return false;
    }
    return true;
  }

  Future<String> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
      },
    );
    final token = data['token'] as String;
    await _api.saveToken(token);
    return token;
  }

  Future<String> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final token = data['token'] as String;
    await _api.saveToken(token);
    return token;
  }

  /// Signs in with Google on Android/iOS. Not available on web - see
  /// [GoogleSignIn.supportsAuthenticate], which the web plugin always reports
  /// false because Google's web SDK requires its own rendered button rather
  /// than a programmatic call.
  Future<String> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    if (!googleSignIn.supportsAuthenticate()) {
      throw ApiException('Google sign-in is not available on this platform yet.');
    }

    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      throw ApiException(e.description ?? 'Google sign-in failed.');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw ApiException('Google did not return an ID token.');
    }

    final data = await _api.post('/auth/google', data: {'idToken': idToken});
    final token = data['token'] as String;
    await _api.saveToken(token);
    return token;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    await GoogleSignIn.instance.initialize(
      serverClientId: webClientId.isEmpty ? null : webClientId,
    );
    _googleSignInInitialized = true;
  }

  Future<void> signOut() async {
    await _api.clearToken();
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Best-effort - a failed local Google sign-out shouldn't block app sign-out.
      }
    }
  }

  Future<void> deleteAccount() async {
    await _api.delete('/profile');
    await signOut();
  }

  /// The signed-in user's email (the JWT's `sub` claim), or null if there is
  /// no stored token.
  Future<String?> currentUserEmail() async {
    final token = await _api.getToken();
    if (token == null) return null;
    return emailFromToken(token);
  }

  /// Reads the `sub` claim straight out of a specific JWT, without touching
  /// whatever token is currently stored. Used by [StepTracker], which pins
  /// itself to one captured token for its whole lifetime rather than the
  /// ambient (mutable) signed-in session - see its class doc for why.
  String? emailFromToken(String jwt) => _decodePayload(jwt)?['sub'] as String?;

  bool _isExpired(String jwt) {
    final payload = _decodePayload(jwt);
    if (payload == null) return true;
    final exp = payload['exp'] as int?;
    if (exp == null) return false;
    return DateTime.now().millisecondsSinceEpoch >= exp * 1000;
  }

  Map<String, dynamic>? _decodePayload(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      return jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
