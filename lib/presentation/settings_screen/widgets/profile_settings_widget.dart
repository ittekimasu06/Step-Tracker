import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ProfileSettingsWidget extends StatefulWidget {
  final String userName;
  final int userAge;
  final double weightKg;
  final double heightCm;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<double> onHeightChanged;

  const ProfileSettingsWidget({
    required this.userName,
    required this.userAge,
    required this.weightKg,
    required this.heightCm,
    required this.onNameChanged,
    required this.onAgeChanged,
    required this.onWeightChanged,
    required this.onHeightChanged,
    super.key,
  });

  @override
  State<ProfileSettingsWidget> createState() => _ProfileSettingsWidgetState();
}

class _ProfileSettingsWidgetState extends State<ProfileSettingsWidget> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _ageController = TextEditingController(text: widget.userAge.toString());
    _weightController = TextEditingController(
      text: widget.weightKg.toStringAsFixed(1),
    );
    _heightController = TextEditingController(
      text: widget.heightCm.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  String get _initials {
    final words = widget.userName.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('PROFILE'),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.stepsGreen.withAlpha(153),
                      AppTheme.activeBlue.withAlpha(153),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _GlassTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  keyboardType: TextInputType.name,
                  onChanged: widget.onNameChanged,
                ),
              ),
            ],
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
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) widget.onAgeChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTextField(
                  controller: _weightController,
                  label: 'Weight',
                  suffix: 'kg',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) widget.onWeightChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTextField(
                  controller: _heightController,
                  label: 'Height',
                  suffix: 'cm',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) widget.onHeightChanged(parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _sectionLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontFamily: 'Manrope',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Color(0xFF888888),
      letterSpacing: 1.2,
    ),
  );
}

class _GlassTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;

  const _GlassTextField({
    required this.controller,
    required this.label,
    this.suffix,
    required this.keyboardType,
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
            ? Colors.white.withAlpha(20)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused
              ? AppTheme.stepsGreen.withAlpha(128)
              : Colors.white.withAlpha(20),
          width: 1,
        ),
      ),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          onChanged: widget.onChanged,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFE6E6E6),
          ),
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: _focused ? AppTheme.stepsGreen : const Color(0xFF888888),
            ),
            suffixText: widget.suffix,
            suffixStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: Color(0xFF888888),
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
