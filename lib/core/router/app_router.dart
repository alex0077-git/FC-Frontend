import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Widget _blankPage(BuildContext context, GoRouterState state) {
  return const Scaffold();
}

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: _blankPage),
    GoRoute(path: '/map', builder: _blankPage),
    GoRoute(path: '/ground-plan', builder: _blankPage),
    GoRoute(path: '/job-execution', builder: _blankPage),
    GoRoute(path: '/profile', builder: _blankPage),
    GoRoute(path: '/settings/calibration', builder: _blankPage),
    GoRoute(path: '/settings/battery', builder: _blankPage),
    GoRoute(path: '/settings/flight-parameters', builder: _blankPage),
  ],
);
