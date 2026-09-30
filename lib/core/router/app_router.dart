import 'package:fc_frontend/core/widgets/bottom_nav_bar.dart';
import 'package:fc_frontend/features/landing/landing_page.dart';
import 'package:fc_frontend/features/map_flight/map_flight_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget _blankPage(BuildContext context, GoRouterState state) {
  return const SizedBox.expand();
}

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNavBar(),
    );
  }
}

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingPage(),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapFlightPage(),
        ),
        GoRoute(path: '/ground-plan', builder: _blankPage),
        GoRoute(path: '/job-execution', builder: _blankPage),
        GoRoute(path: '/profile', builder: _blankPage),
        GoRoute(path: '/settings/calibration', builder: _blankPage),
        GoRoute(path: '/settings/battery', builder: _blankPage),
        GoRoute(path: '/settings/flight-parameters', builder: _blankPage),
      ],
    ),
  ],
);
