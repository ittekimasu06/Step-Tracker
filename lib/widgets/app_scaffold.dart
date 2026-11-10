import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';

class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    // The body's own width cap lives per-screen now (each screen's header
    // sliver stays full-bleed; its content slivers are the ones capped - see
    // e.g. ActivityDashboardScreen._buildContentSlivers), so the body here is
    // left unconstrained. The nav bar gets its own, narrower cap instead -
    // web only, naturally responsive since it's a no-op below its maxWidth.
    Widget navBar = AppNavigation(navigationShell: navigationShell);
    if (kIsWeb) {
      // Row, not Center/Align - those size themselves to fill all available
      // space on any loose axis, and Scaffold gives bottomNavigationBar a
      // very generous height allowance, which blew this up to cover most of
      // the screen. Row only takes the height its child needs.
      navBar = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: navBar,
          ),
        ],
      );
    }
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: navBar,
    );
  }
}
