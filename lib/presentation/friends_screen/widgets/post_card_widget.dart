import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/avatar_circle.dart';

/// Renders one Connect-feed post: author header, three progress bars (steps/active/calories,
/// using this app's established metric colors - see `metric_cards_row_widget.dart`), and a
/// tappable like row. All three stats and their goals come from [post] as a frozen snapshot -
/// this widget never recomputes anything live.
class PostCardWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback? onToggleLike;

  const PostCardWidget({required this.post, this.onToggleLike, super.key});

  @override
  Widget build(BuildContext context) {
    final fullName = post['fullName'] as String? ?? 'Unknown user';
    final postDate = post['postDate'] as String? ?? '';
    final likeCount = post['likeCount'] as int? ?? 0;
    final likedByMe = post['likedByMe'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(avatarId: post['avatarId'] as String?, displayName: fullName, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      postDate,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Progress of\n$postDate',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _metricBar(
            context,
            label: 'Ste',
            color: AppTheme.stepsGreen,
            value: post['stepCount'] as int? ?? 0,
            goal: post['stepGoal'] as int? ?? 1,
          ),
          const SizedBox(height: 8),
          _metricBar(
            context,
            label: 'Tim',
            color: AppTheme.activeBlue,
            value: post['activeMinutes'] as int? ?? 0,
            goal: post['activeMinutesGoal'] as int? ?? 1,
          ),
          const SizedBox(height: 8),
          _metricBar(
            context,
            label: 'Cal',
            color: AppTheme.caloriesPurple,
            value: post['calorieCount'] as int? ?? 0,
            goal: post['calorieGoal'] as int? ?? 1,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onToggleLike,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(
                  likedByMe ? Icons.favorite : Icons.favorite_border,
                  size: 18,
                  color: likedByMe ? AppTheme.caloriesPurple : AppTheme.textSecondary(context),
                ),
                const SizedBox(width: 6),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBar(
    BuildContext context, {
    required String label,
    required Color color,
    required int value,
    required int goal,
  }) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Container(
          width: 36,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withAlpha(38),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value / $goal',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
