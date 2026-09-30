import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const FcApp(),
    ),
  );
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
