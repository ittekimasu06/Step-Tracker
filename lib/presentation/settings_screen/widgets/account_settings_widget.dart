import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_theme.dart';

/// Reads the signed-in user's email from [AuthProvider] rather than self-fetching it (unlike
/// ProfileSettingsWidget) - this widget lives inside the StatefulShellRoute's IndexedStack, so
/// it's never disposed/recreated when the user navigates to ChangeEmailScreen and back
/// (whether via pop or go()); a self-fetch on initState alone would keep showing the address
/// from whenever this widget first mounted. Watching the provider instead picks up the new
/// address the moment ChangeEmailScreen's confirm step commits it.
class AccountSettingsWidget extends StatelessWidget {
  const AccountSettingsWidget({super.key});

  Future<void> _openChangeEmail(BuildContext context) {
    return context.push(AppRoutes.changeEmailScreen);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthProvider>().currentEmail;
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
            'ACCOUNT',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary(context),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _openChangeEmail(context),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.stepsGreen.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.alternate_email_rounded,
                      color: AppTheme.stepsGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textBright(context),
                          ),
                        ),
                        Text(
                          email ?? 'Loading...',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppTheme.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textMuted(context),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
