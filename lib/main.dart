import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: FcApp()));
}

class FcApp extends StatelessWidget {
  const FcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FC Frontend',
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
