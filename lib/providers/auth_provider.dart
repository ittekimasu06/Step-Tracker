import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // The signed-in user's email, kept here (rather than re-fetched by whichever widget wants
  // to show it) because AccountSettingsWidget lives inside the StatefulShellRoute's
  // IndexedStack - it's never disposed/recreated when navigation returns to Settings (via
  // push/pop OR go()), so a self-fetch on initState alone would go stale after
  // confirmEmailChange. Watching this field instead makes it update the moment the change
  // commits, regardless of how the user gets back to Settings.
  String? _currentEmail;

  // Set after a register call or a login call rejected specifically for an
  // unverified email (HTTP 403 - see AuthService.signInWithEmail's caller
  // below) - the UI checks this to decide whether to route to
  // VerifyEmailScreen instead of just showing an inline error. Cleared on a
  // successful verifyEmail.
  String? _pendingVerificationEmail;

  // Set by [requestEmailChange] on success, purely so ChangeEmailScreen's confirm step can
  // display "Code sent to {email}" - unrelated to [_pendingVerificationEmail] above, which
  // exists to survive the router's pre-auth redirect (see app_routes.dart's isAuthRoute
  // check); this flow only ever runs while already authenticated, so it doesn't need that.
  String? _pendingNewEmail;

  bool get isAuthenticated => _isAuthenticated;
  String? get currentEmail => _currentEmail;
  bool get profileCompleted => _profileCompleted;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  String? get pendingNewEmail => _pendingNewEmail;

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
      _currentEmail = await _authService.currentUserEmail();
      await _resumeBackgroundTrackingIfPermitted();
    }
    _isAuthenticated = hasSession;
    _isInitialized = true;
    notifyListeners();
  }

  void _handleUnauthorized() {
    if (!_isAuthenticated) return;
    _isAuthenticated = false;
    _currentEmail = null;
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

  /// Does *not* sign the user in on success - see AuthService.registerWithEmail's
  /// doc. A true return means "the code was sent, go to VerifyEmailScreen"
  /// (check [pendingVerificationEmail]), not "you're logged in now".
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
      _pendingVerificationEmail = email;
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
      _currentEmail = email;
      await _resumeBackgroundTrackingIfPermitted();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // 403 is only ever returned by /auth/login for one reason - see
      // AuthController.login's EmailNotVerifiedException branch - so the
      // status code alone is enough to route to VerifyEmailScreen instead
      // of just showing e.message as a dead-end error.
      if (e.statusCode == 403) {
        _pendingVerificationEmail = email;
      }
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Completes the login that [signUpWithEmail]/a 403 [signInWithEmail] left
  /// pending.
  Future<bool> verifyEmail(String code) async {
    final email = _pendingVerificationEmail;
    if (email == null) {
      _setError('Nothing to verify.');
      return false;
    }
    _setLoading(true);
    _setError(null);
    try {
      await _authService.verifyEmail(email: email, code: code);
      _pendingVerificationEmail = null;
      _profileCompleted = await ProfileService.instance.shouldSkipProfileSetup();
      _currentEmail = email;
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

  Future<bool> resendVerificationCode() async {
    final email = _pendingVerificationEmail;
    if (email == null) return false;
    _setLoading(true);
    _setError(null);
    try {
      await _authService.resendVerificationCode(email);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestEmailChange({
    required String currentPassword,
    required String newEmail,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.requestEmailChange(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );
      _pendingNewEmail = newEmail;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmEmailChange(String code) async {
    _setLoading(true);
    _setError(null);
    try {
      final token = await _authService.confirmEmailChange(code);
      _currentEmail = _authService.emailFromToken(token);
      _pendingNewEmail = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resendEmailChangeCode() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.resendEmailChangeCode();
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
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
      _currentEmail = await _authService.currentUserEmail();
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
      _stopBackgroundTracking();
      _isAuthenticated = false;
      _currentEmail = null;
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  void _stopBackgroundTracking() {
    if (kIsWeb || !Platform.isAndroid) return;
    FlutterBackgroundService().invoke('stop');
  }

  /// Permanently deletes the account, then signs out locally.
  Future<bool> deleteAccount() async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.deleteAccount();
      _stopBackgroundTracking();
      _isAuthenticated = false;
      _currentEmail = null;
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
