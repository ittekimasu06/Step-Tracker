import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/step_tracker.dart';

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

  /// Covers the *returning*-user case for background step tracking: starts
  /// the service if permission was already granted in a previous session, so
  /// tracking resumes on app open even if the user lands on a tab other than
  /// the dashboard this session (which is where permission is first
  /// *requested* - see ActivityDashboardScreen - since prompting here, before
  /// any UI has been shown, would be both fragile with no guaranteed Android
  /// Activity yet and a UX regression from today's existing prompt-on-reaching
  /// -dashboard behavior). Status-only, never `.request()` - same reasoning.
  Future<void> _resumeBackgroundTrackingIfPermitted() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final granted = await Permission.activityRecognition.status;
    if (!granted.isGranted) return;
    if (!(await FlutterBackgroundService().isRunning())) {
      await FlutterBackgroundService().startService();
    }
  }

  /// Restores auth state from the securely stored token. Call once at app
  /// startup, before the first frame that depends on [isAuthenticated].
  Future<void> initialize() async {
    final hasSession = await _authService.hasValidStoredSession();
    if (hasSession) {
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
      await _resumeBackgroundTrackingIfPermitted();
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
      await _resumeBackgroundTrackingIfPermitted();
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
      await _resumeBackgroundTrackingIfPermitted();
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
      await _resumeBackgroundTrackingIfPermitted();
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
      await _stopBackgroundTracking();
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  /// Stops tracking and marks the stop as deliberate (see
  /// StepTracker.markExplicitlyPaused) - same reasoning as the Settings
  /// "Close App" button: sign-out is just as much a deliberate "turn
  /// tracking off" as closing the app is, so steps/active time that
  /// accumulate while signed out shouldn't be silently backfilled once
  /// tracking resumes, whether that's this same account signing back in or
  /// a different one on the same device.
  Future<void> _stopBackgroundTracking() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await StepTracker.markExplicitlyPaused();
    FlutterBackgroundService().invoke('stop');
  }

  /// Permanently deletes the account, then signs out locally.
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.deleteAccount();
      await _stopBackgroundTracking();
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
