import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A circular avatar: the picked image asset for a real `avatarId`, or an
/// initials-on-gradient placeholder for `null`/`'default'` (the sentinel
/// duality mirrors the backend's `UserProfile.avatarId` - see its doc).
class AvatarCircle extends StatelessWidget {
  final String? avatarId;
  final String displayName;
  final double size;

  const AvatarCircle({
    super.key,
    required this.avatarId,
    required this.displayName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final id = avatarId;
    if (id != null && id != 'default') {
      return ClipOval(
        child: Image.asset(
          'assets/images/$id',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initialsCircle(),
        ),
      );
    }
    return _initialsCircle();
  }

  Widget _initialsCircle() {
    return Container(
      width: size,
      height: size,
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
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: size * 0.32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String get _initials {
    final name = displayName.trim();
    if (name.isEmpty) return '';
    final words = name.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    }
    return (words.first[0] + words.last[0]).toUpperCase();
  }
}
