import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class GoalSettingsWidget extends StatelessWidget {
  final int stepGoal;
  final int activeTimeGoal;
  final int calorieGoal;
  final ValueChanged<int> onStepGoalChanged;
  final ValueChanged<int> onActiveTimeChanged;
  final ValueChanged<int> onCalorieGoalChanged;

  const GoalSettingsWidget({
    required this.stepGoal,
    required this.activeTimeGoal,
    required this.calorieGoal,
    required this.onStepGoalChanged,
    required this.onActiveTimeChanged,
    required this.onCalorieGoalChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY GOALS',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Step Goal',
            value: stepGoal.toDouble(),
            min: 1000,
            max: 20000,
            divisions: 190,
            color: AppTheme.stepsGreen,
            displayValue: _formatSteps(stepGoal),
            unit: 'steps',
            onChanged: (v) => onStepGoalChanged(v.round()),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Active Time Goal',
            value: activeTimeGoal.toDouble(),
            min: 10,
            max: 180,
            divisions: 170,
            color: AppTheme.activeBlue,
            displayValue: '$activeTimeGoal',
            unit: 'min',
            onChanged: (v) => onActiveTimeChanged(v.round()),
          ),
          const SizedBox(height: 16),
          _GoalSliderRow(
            label: 'Calorie Goal',
            value: calorieGoal.toDouble(),
            min: 100,
            max: 2000,
            divisions: 190,
            color: AppTheme.caloriesPurple,
            displayValue: '$calorieGoal',
            unit: 'kcal',
            onChanged: (v) => onCalorieGoalChanged(v.round()),
          ),
        ],
      ),
    );
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(steps % 1000 == 0 ? 0 : 1)}k';
    }
    return steps.toString();
  }
}

class _GoalEditDialog extends StatefulWidget {
  final String label;
  final int initialValue;
  final int min;
  final int max;
  final String unit;
  final Color color;

  const _GoalEditDialog({
    required this.label,
    required this.initialValue,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
  });

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text);
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.label,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.textBright(context),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: widget.color,
            ),
            decoration: InputDecoration(
              suffixText: widget.unit,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: widget.color, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            'Range: ${widget.min} - ${widget.max} ${widget.unit}',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(
            'Save',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              color: widget.color,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final String displayValue;
  final String unit;
  final ValueChanged<double> onChanged;

  const _GoalSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.displayValue,
    required this.unit,
    required this.onChanged,
  });

  Future<void> _showEditDialog(BuildContext context) async {
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return _GoalEditDialog(
          label: label,
          initialValue: value.round(),
          min: min.toInt(),
          max: max.toInt(),
          unit: unit,
          color: color,
        );
      },
    );
    if (result == null) return;
    final clamped = result.clamp(min.toInt(), max.toInt());
    onChanged(clamped.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textBright(context),
              ),
            ),
            InkWell(
              onTap: () => _showEditDialog(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: color,
            inactiveTrackColor: color.withAlpha(51),
            thumbColor: color,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayColor: color.withAlpha(38),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${min.toInt()}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: AppTheme.textMuted(context),
              ),
            ),
            Text(
              '${max.toInt()}',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 10,
                color: AppTheme.textMuted(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}