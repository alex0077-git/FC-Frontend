import 'package:fc_frontend/core/widgets/bottom_nav_bar.dart';
import 'package:fc_frontend/core/widgets/flight_status_bar.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:fc_frontend/features/job_execution/job_execution_page.dart';
import 'package:fc_frontend/features/landing/landing_page.dart';
import 'package:fc_frontend/features/map_flight/map_flight_page.dart';
import 'package:fc_frontend/features/profile/profile_page.dart';
import 'package:fc_frontend/features/settings/battery/battery_settings_page.dart';
import 'package:fc_frontend/features/settings/calibration/calibration_page.dart';
import 'package:fc_frontend/features/settings/flight_parameters/flight_parameters_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const FlightStatusBar(),
          Expanded(child: child),
        ],
      ),
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
        GoRoute(
          path: '/ground-plan',
          builder: (context, state) => const GroundPlanPage(),
        ),
        GoRoute(
          path: '/job-execution',
          builder: (context, state) => const JobExecutionPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/settings/calibration',
          builder: (context, state) => const CalibrationPage(),
        ),
        GoRoute(
          path: '/settings/battery',
          builder: (context, state) => const BatterySettingsPage(),
        ),
        GoRoute(
          path: '/settings/flight-parameters',
          builder: (context, state) => const FlightParametersPage(),
        ),
      ],
    ),
  ],
);
