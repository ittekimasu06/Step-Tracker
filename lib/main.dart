import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:provider/provider.dart';

import '../core/app_export.dart';
import '../services/background_step_service.dart';
import '../widgets/custom_error_widget.dart';
import './providers/auth_provider.dart';
import './providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configuration only - doesn't touch permissions or start anything itself
  // (see background_step_service.dart's doc), so safe this early.
  await initializeStepTrackingService();

  final authProvider = AuthProvider();
  final themeProvider = ThemeProvider();
  // Restore any previously stored session/theme before the first frame, so
  // the router's initial redirect and the active theme are already correct.
  // Independent I/O (secure storage vs. SharedPreferences), so run them
  // together rather than sequentially.
  await Future.wait([authProvider.initialize(), themeProvider.initialize()]);
  final router = buildAppRouter(authProvider);

  bool hasShownError = false;

  // Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // Device orientation lock - DO NOT REMOVE
  Future.wait([
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  ]).then((value) {
    GoRouter.optionURLReflectsImperativeAPIs = true;
    runApp(
      MyApp(
        authProvider: authProvider,
        themeProvider: themeProvider,
        router: router,
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({
    required this.authProvider,
    required this.themeProvider,
    required this.router,
    super.key,
  });

  final AuthProvider authProvider;
  final ThemeProvider themeProvider;
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProvider),
          ChangeNotifierProvider.value(value: themeProvider),
        ],
        child: Sizer(
          builder: (context, orientation, screenType) {
            // This `context` is a descendant of the MultiProvider above -
            // the outer MyApp.build `context` parameter is NOT, and reading
            // ThemeProvider with that one instead would throw
            // ProviderNotFoundException at runtime.
            final themeMode = context.watch<ThemeProvider>().themeMode;
            return MaterialApp.router(
              title: 'steptrack',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,

              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(1.0)),
                  child: child!,
                );
              },

              debugShowCheckedModeBanner: false,
              routerConfig: router,
            );
          },
        ),
    );
  }
}
