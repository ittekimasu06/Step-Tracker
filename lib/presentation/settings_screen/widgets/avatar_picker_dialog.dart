import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

import '../../../theme/app_theme.dart';

/// Shows the avatar picker (mockup: "Select avatar") and resolves to the
/// chosen avatar id - `'default'` for the initials-gradient option, or an
/// `assets/images/avatar_*.png`-style filename for a real image - or `null`
/// if the user cancelled. Avatar images are discovered at runtime via
/// [AssetManifest], not a hardcoded list, so dropping new `avatar_*` files
/// into `assets/images/` (already declared in pubspec.yaml - no new asset
/// directory needed, per this project's "DO NOT ADD NEW ASSET DIRECTORIES"
/// rule) needs zero Dart changes to show up here.
Future<String?> showAvatarPickerDialog(
  BuildContext context, {
  required String? currentAvatarId,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _AvatarPickerDialog(initialAvatarId: currentAvatarId ?? 'default'),
  );
}

class _AvatarPickerDialog extends StatefulWidget {
  final String initialAvatarId;

  const _AvatarPickerDialog({required this.initialAvatarId});

  @override
  State<_AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<_AvatarPickerDialog> {
  late String _selected = widget.initialAvatarId;
  List<String>? _avatarFiles;

  @override
  void initState() {
    super.initState();
    _loadAvatarFiles();
  }

  Future<void> _loadAvatarFiles() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest.listAssets();
    final files = assets
        .where((path) => path.startsWith('assets/images/avatar_'))
        .map((path) => path.substring('assets/images/'.length))
        .toList()
      ..sort();
    if (!mounted) return;
    setState(() => _avatarFiles = files);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Select avatar',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _avatarFiles == null
            ? const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              )
            : Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildOption('default'),
                  for (final file in _avatarFiles!) _buildOption(file),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(fontFamily: 'Manrope', color: AppTheme.textSecondary(context)),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text(
            'OK',
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, color: AppTheme.stepsGreen),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(String avatarId) {
    final isSelected = _selected == avatarId;
    return GestureDetector(
      onTap: () => setState(() => _selected = avatarId),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.stepsGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: avatarId == 'default'
            ? _buildInitialsCircle()
            : ClipOval(
                child: Image.asset(
                  'assets/images/$avatarId',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  Widget _buildInitialsCircle() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.stepsGreen.withAlpha(153),
            AppTheme.activeBlue.withAlpha(153),
          ],
        ),
        shape: BoxShape.circle,
      ),
    );
  }
}
