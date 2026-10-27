import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// The friend-request status -> button/pill mapping, shared between the search-results list
/// and [UserProfilePreviewSheet] (both show a user plus "where do things stand" action) - was
/// previously duplicated inline in `friends_screen.dart`'s `_buildStatusAction`/`_pill`.
class FriendStatusAction extends StatelessWidget {
  final String status;
  final VoidCallback onSendRequest;

  const FriendStatusAction({required this.status, required this.onSendRequest, super.key});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'FRIENDS':
        return _pill(context, 'Friends', AppTheme.textSecondary(context));
      case 'PENDING_SENT':
        return _pill(context, 'Requested', AppTheme.textSecondary(context));
      case 'PENDING_RECEIVED':
        return _pill(context, 'Check Requests', AppTheme.stepsGreen);
      default:
        return TextButton(
          onPressed: onSendRequest,
          child: const Text('Add', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
        );
    }
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
