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
    final innerNavBar = AppNavigation(navigationShell: navigationShell);
    Widget navBar = innerNavBar;
    if (kIsWeb) {
      // AppNavigation's own Container has no explicit width - it only fills
      // whatever it's given because Scaffold normally hands
      // bottomNavigationBar *tight* width constraints (exactly the screen
      // width). A plain Row/Center here gives it *loose* constraints
      // instead, so it'd just shrink to its own content size. This SizedBox
      // re-imposes a tight width, capped at 760, so it fills up to that cap
      // and visibly shrinks below it as the viewport narrows.
      //
      // Deliberately MediaQuery's size, not LayoutBuilder's constraints here
      // - Scaffold hands the bottomNavigationBar slot an *unbounded* max
      // width (confirmed by this exact bug: every width clamped straight to
      // 760 regardless of an actually-narrower viewport, clipping it), so
      // LayoutBuilder's constraints.maxWidth isn't the real viewport width.
      final viewportWidth = MediaQuery.of(context).size.width;
      final width = viewportWidth > 760 ? 760.0 : viewportWidth;
      navBar = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [SizedBox(width: width, child: innerNavBar)],
      );
    }
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: navBar,
    );
  }
}
