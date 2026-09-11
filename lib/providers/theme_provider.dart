import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

/// Persists the user's Light/Dark/System theme choice. Device-local, not
/// account-specific - the key is deliberately unscoped, unlike
/// `StepTracker`'s per-account keys.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  /// Restores the persisted choice. Call once at app startup, before the
  /// first frame that depends on [themeMode] - same timing as
  /// `AuthProvider.initialize()`.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey);
    _themeMode = _parse(stored) ?? ThemeMode.system;
    notifyListeners();
  }

  /// Updates and notifies immediately, so the toggle feels instant - the
  /// persistence write happens afterward without the caller awaiting it.
  /// Deliberately not `AuthProvider`'s loading-flag-then-notify shape, which
  /// exists for network calls; a local preference write shouldn't gate the UI.
  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
    _persist(mode);
  }

  Future<void> _persist(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _encode(mode));
  }

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode? _parse(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => null,
  };
}
