import 'package:flutter/foundation.dart';

/// Whether Settings' global-Save section (Goals/Units/Notifications - not
/// Profile, which is self-contained with its own inline Save, and not
/// Appearance, which already persists instantly via [ThemeProvider] rather
/// than waiting for Save) has changes not yet committed.
///
/// A singleton rather than a [ChangeNotifierProvider]-scoped instance
/// because the consumer ([AppNavigation]'s tab-tap handler) and the owner
/// ([SettingsScreen]) are siblings in the widget tree, not parent/child -
/// there's no ancestor both can share a `Provider` through without adding
/// one purely for this.
class SettingsDirtyState extends ChangeNotifier {
  static SettingsDirtyState? _instance;
  static SettingsDirtyState get instance => _instance ??= SettingsDirtyState._();
  SettingsDirtyState._();

  bool _value = false;
  bool get value => _value;

  set value(bool v) {
    if (_value == v) return;
    _value = v;
    notifyListeners();
  }

  VoidCallback? _onDiscard;

  /// [SettingsScreen] registers this once (in `initState`) to reset its own
  /// local state back to the last-loaded/saved snapshot when the user
  /// confirms discarding - this class only tracks the boolean flag, it has
  /// no access to Settings' actual field values to reset them itself.
  void registerDiscardHandler(VoidCallback handler) => _onDiscard = handler;

  void unregisterDiscardHandler() => _onDiscard = null;

  /// Called by [AppNavigation] after the user confirms discarding unsaved
  /// Settings changes in the leave-tab guard dialog.
  void discard() {
    _onDiscard?.call();
    value = false;
  }
}
