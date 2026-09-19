import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../../services/profile_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/avatar_circle.dart';
import 'avatar_picker_dialog.dart';

/// The Profile card in Settings - self-contained, unlike every other section
/// on this screen: it fetches and saves its own data directly via
/// [ProfileService] rather than being a controlled widget fed by the parent
/// [SettingsScreen] and persisted through that screen's single global Save.
/// Collapsed shows avatar + username + EDIT; tapping EDIT expands into a full
/// form with its own SAVE, enabled only once something actually changed.
/// Gender is shown but never editable here - this app has never had a
/// Settings-side gender editor, only the one-time choice at profile-setup.
class ProfileSettingsWidget extends StatefulWidget {
  const ProfileSettingsWidget({super.key});

  @override
  State<ProfileSettingsWidget> createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget> {
  bool _expanded = false;
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;
  UserProfile? _profile;
  String? _avatarId;

  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _ageController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _usernameController = TextEditingController();
    _ageController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService.instance.fetchProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _resetFieldsFromProfile();
      _loading = false;
    });
  }

  void _resetFieldsFromProfile() {
    final p = _profile;
    _nameController.text = p?.fullName ?? '';
    _usernameController.text = p?.username ?? '';
    _ageController.text = p?.age?.toString() ?? '';
    _weightController.text = p?.weightKg?.toStringAsFixed(1) ?? '';
    _heightController.text = p?.heightCm?.toStringAsFixed(0) ?? '';
    _descriptionController.text = p?.description ?? '';
    _avatarId = p?.avatarId;
  }

  bool get _hasChanges {
    final p = _profile;
    if (p == null) return false;
    return _nameController.text.trim() != p.fullName ||
        _usernameController.text.trim() != (p.username ?? '') ||
        _ageController.text.trim() != (p.age?.toString() ?? '') ||
        _weightController.text.trim() != (p.weightKg?.toStringAsFixed(1) ?? '') ||
        _heightController.text.trim() != (p.heightCm?.toStringAsFixed(0) ?? '') ||
        _descriptionController.text.trim() != (p.description ?? '') ||
        (_avatarId ?? 'default') != (p.avatarId ?? 'default');
  }

  // TapRegion's outside-tap detection listens globally for pointer-down
  // events, not just within this widget's own subtree - a tap inside the
  // avatar picker's Dialog (a separate route/overlay) still counts as
  // "outside" and would otherwise collapse-and-discard the card while the
  // picker is open. Guarded off for the duration of that dialog.
  bool _pickerOpen = false;

  void _startEditing() => setState(() => _expanded = true);

  void _cancelEditing() {
    if (_pickerOpen) return;
    setState(() {
      _resetFieldsFromProfile();
      _expanded = false;
      _errorMessage = null;
    });
  }

  Future<void> _pickAvatar() async {
    _pickerOpen = true;
    final selected = await showAvatarPickerDialog(context, currentAvatarId: _avatarId);
    _pickerOpen = false;
    if (selected != null) {
      setState(() => _avatarId = selected);
    }
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username is required');
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final updated = UserProfile(
      id: _profile?.id ?? '',
      email: _profile?.email ?? '',
      username: username,
      fullName: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      avatarId: _avatarId ?? 'default',
      age: int.tryParse(_ageController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      heightCm: double.tryParse(_heightController.text.trim()),
      gender: _profile?.gender,
      profileCompleted: _profile?.profileCompleted ?? true,
      stepGoal: _profile?.stepGoal,
      activeMinutesGoal: _profile?.activeMinutesGoal,
      calorieGoal: _profile?.calorieGoal,
    );

    try {
      await ProfileService.instance.saveProfile(updated);
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _saving = false;
        _expanded = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return TapRegion(
      enabled: _expanded,
      onTapOutside: (_) => _cancelEditing(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(),
            const SizedBox(height: 12),
            _expanded ? _buildExpanded() : _buildCollapsed(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        _sectionLabel(context, 'PROFILE'),
        const Spacer(),
        if (_saving)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton(
            onPressed: _expanded ? (_hasChanges ? _save : null) : _startEditing,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _expanded ? 'SAVE' : 'EDIT',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _expanded && !_hasChanges
                    ? AppTheme.textDisabled(context)
                    : AppTheme.stepsGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCollapsed() {
    return Row(
      children: [
        AvatarCircle(avatarId: _avatarId, displayName: _nameController.text, size: 56),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            _profile?.username ?? '',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpanded() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarCircle(avatarId: _avatarId, displayName: _nameController.text, size: 56),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.stepsGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 12,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _GlassTextField(
                controller: _nameController,
                label: 'Full Name',
                keyboardType: TextInputType.name,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GlassTextField(
          controller: _usernameController,
          label: 'Username',
          keyboardType: TextInputType.text,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _GlassTextField(
                controller: _ageController,
                label: 'Age',
                suffix: 'yrs',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GlassTextField(
                controller: _weightController,
                label: 'Weight',
                suffix: 'kg',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GlassTextField(
                controller: _heightController,
                label: 'Height',
                suffix: 'cm',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildGenderDisplay(),
        const SizedBox(height: 12),
        _GlassTextField(
          controller: _descriptionController,
          label: 'Description',
          keyboardType: TextInputType.multiline,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderDisplay() {
    final gender = _profile?.gender;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.overlay(context, 10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.overlay(context, 20), width: 1),
      ),
      child: Row(
        children: [
          Text(
            'Gender',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const Spacer(),
          Text(
            gender?.isNotEmpty == true ? gender! : 'Not set',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

}

Widget _sectionLabel(BuildContext context, String text) {
  return Text(
    text,
    style: TextStyle(
      fontFamily: 'Manrope',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: AppTheme.textSecondary(context),
      letterSpacing: 1.2,
    ),
  );
}

class _GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final TextInputType keyboardType;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.suffix,
    required this.keyboardType,
    this.maxLines = 1,
    required this.onChanged,
  });

  @override
  State<_GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<_GlassTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _focused
            ? AppTheme.overlay(context, 20)
            : AppTheme.overlay(context, 10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused
              ? AppTheme.stepsGreen.withAlpha(128)
              : AppTheme.overlay(context, 20),
          width: 1,
        ),
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: _focused
                  ? AppTheme.stepsGreen
                  : AppTheme.textSecondary(context),
            ),
            suffixText: widget.suffix,
            suffixStyle: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }
}
