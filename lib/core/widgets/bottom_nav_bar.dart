import 'package:fc_frontend/core/widgets/flight_command_bar.dart';
import 'package:fc_frontend/core/widgets/ground_plan_bar.dart';
import 'package:fc_frontend/core/widgets/home_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(height: 72, child: _barFor(location)),
      ),
    );
  }

  Widget _barFor(String location) {
    if (location == '/map') {
      return const FlightCommandBar();
    }
    if (location == '/ground-plan') {
      return const GroundPlanBar();
    }
    return const _HomeOnlyBar();
  }
}

class _HomeOnlyBar extends StatelessWidget {
  const _HomeOnlyBar();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 72, child: HomeButton()),
      ],
    );
  }
}
