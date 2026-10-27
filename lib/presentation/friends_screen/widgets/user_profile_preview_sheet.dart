import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/avatar_circle.dart';
import 'friend_status_action.dart';

/// Shown via `showModalBottomSheet` when tapping a user in the Connect tab's discover row -
/// avatar, full name, @username, and the same friend-action button `friends_screen.dart`'s
/// search results use (see [FriendStatusAction]).
class UserProfilePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onSendRequest;

  const UserProfilePreviewSheet({required this.user, required this.onSendRequest, super.key});

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> user,
    required VoidCallback onSendRequest,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => UserProfilePreviewSheet(user: user, onSendRequest: onSendRequest),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = user['fullName'] as String? ?? 'Unknown user';
    final username = user['username'] as String?;
    final status = user['status'] as String? ?? 'NONE';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarCircle(avatarId: user['avatarId'] as String?, displayName: fullName, size: 72),
            const SizedBox(height: 14),
            Text(
              fullName,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (username != null && username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '@$username',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppTheme.textSecondary(context),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FriendStatusAction(
              status: status,
              onSendRequest: () {
                Navigator.of(context).pop();
                onSendRequest();
              },
            ),
          ],
        ),
      ),
    );
  }
}
