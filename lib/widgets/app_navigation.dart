import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/settings_dirty_state.dart';
import '../theme/app_theme.dart';

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.branchIndex,
  });
}

class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  int _selectedVisualIndex = 0;

  static const List<_TabSpec> _tabs = [
    _TabSpec(
      label: 'Activity',
      icon: Icons.directions_run_outlined,
      selectedIcon: Icons.directions_run,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'Consultant',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'Friends',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      branchIndex: 3,
    ),
  ];

  @override
  void didUpdateWidget(AppNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.navigationShell.currentIndex;
    if (current != _selectedVisualIndex) {
      setState(() => _selectedVisualIndex = current);
    }
  }

  Future<void> _onTabTap(_TabSpec tab, bool isStub) async {
    if (isStub) return;
    final targetBranch = tab.branchIndex!;
    final leavingDirtySettings = widget.navigationShell.currentIndex == 3 &&
        targetBranch != 3 &&
        SettingsDirtyState.instance.value;

    // The tab highlight and goBranch must both wait on the dialog's result,
    // not happen before it - otherwise the highlight visibly jumps to the
    // new tab and jumps back on Cancel.
    if (leavingDirtySettings) {
      final discard = await _confirmDiscardSettingsDialog();
      if (discard != true) return;
      SettingsDirtyState.instance.discard();
    }

    if (!mounted) return;
    setState(() {
      _selectedVisualIndex = _tabs.indexWhere(
        (t) => t.branchIndex == targetBranch,
      );
    });
    widget.navigationShell.goBranch(
      targetBranch,
      initialLocation: targetBranch == widget.navigationShell.currentIndex,
    );
  }

  Future<bool?> _confirmDiscardSettingsDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard Changes?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'You have unsaved changes on this screen. Leaving now will discard them.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Manrope', color: AppTheme.textSecondary(ctx)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Discard',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withAlpha(191),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.overlay(context, 20), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = _selectedVisualIndex == i;
                final isStub = tab.branchIndex == null;

                return GestureDetector(
                  onTap: () => _onTabTap(tab, isStub),
                  behavior: HitTestBehavior.opaque,
                  child: Opacity(
                    opacity: isStub ? 0.4 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isActive ? 20 : 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.stepsGreen.withAlpha(38)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? tab.selectedIcon : tab.icon,
                            color: isActive
                                ? AppTheme.stepsGreen
                                : AppTheme.textSecondary(context),
                            size: 22,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: isActive
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      tab.label,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.stepsGreen,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
