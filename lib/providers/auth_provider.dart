import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _errorMessage;
  // Whether the just-signed-in user should skip profile-setup. Fetched and
  // settled *before* [_isAuthenticated] flips true and [notifyListeners]
  // fires, not after - the router's `redirect` (via `refreshListenable`)
  // reacts to that notification immediately and would otherwise race ahead
  // to the dashboard, unmounting the login/register screen before a
  // separate post-await navigation call could ever run.
  bool _profileCompleted = true;

  bool get isAuthenticated => _isAuthenticated;
  bool get profileCompleted => _profileCompleted;

  /// True once the stored-session check on startup has finished. The router
  /// uses this to hold on a splash state rather than flashing the login
  /// screen before that check completes.
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    ApiClient.instance.onUnauthorized = _handleUnauthorized;
  }

  /// Restores auth state from the securely stored token. Call once at app
  /// startup, before the first frame that depends on [isAuthenticated].
  Future<void> initialize() async {
    final hasSession = await _authService.hasValidStoredSession();
    if (hasSession) {
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
    }
    _isAuthenticated = hasSession;
    _isInitialized = true;
    notifyListeners();
  }

  void _handleUnauthorized() {
    if (!_isAuthenticated) return;
    _isAuthenticated = false;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.registerWithEmail(
        email: email,
        username: username,
        password: password,
      );
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithGoogle();
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signOut();
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  /// Permanently deletes the account, then signs out locally.
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.deleteAccount();
      _isAuthenticated = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to delete account. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
