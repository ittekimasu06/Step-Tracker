import 'package:go_router/go_router.dart';

import '../presentation/activity_dashboard_screen/activity_dashboard_screen.dart';
import '../presentation/consultant_screen/consultant_screen.dart';
import '../presentation/friend_requests_screen/friend_requests_screen.dart';
import '../presentation/friends_screen/friends_screen.dart';
import '../presentation/settings_screen/settings_screen.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/auth/register_screen.dart';
import '../presentation/auth/profile_setup_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_scaffold.dart';

class AppRoutes {
  static const String initial = '/login';
  static const String loginScreen = '/login';
  static const String registerScreen = '/register';
  static const String profileSetupScreen = '/profile-setup';
  static const String activityDashboardScreen = '/activity-dashboard-screen';
  static const String consultantScreen = '/consultant-screen';
  static const String friendsScreen = '/friends-screen';
  static const String friendRequestsScreen = '/friend-requests-screen';
  static const String settingsScreen = '/settings-screen';
}

/// Builds the app's router against [authProvider]. Call once, after
/// [AuthProvider.initialize] has completed, so the initial route decision
/// already reflects any restored session.
GoRouter buildAppRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: AppRoutes.loginScreen,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isAuthRoute =
          state.matchedLocation == AppRoutes.loginScreen ||
          state.matchedLocation == AppRoutes.registerScreen;

      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.loginScreen;
      }
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.activityDashboardScreen;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.loginScreen,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerScreen,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileSetupScreen,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.friendRequestsScreen,
        builder: (context, state) => const FriendRequestsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.activityDashboardScreen,
                builder: (context, state) => const ActivityDashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.consultantScreen,
                builder: (context, state) => const ConsultantScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.friendsScreen,
                builder: (context, state) => const FriendsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settingsScreen,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
