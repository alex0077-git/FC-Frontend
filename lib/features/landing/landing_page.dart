import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          // A full-screen background image can replace this gradient:
          // image: DecorationImage(
          //   image: AssetImage('assets/images/landing_background.png'),
          //   fit: BoxFit.cover,
          // ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10192B), AppTheme.background, Color(0xFF08101C)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: const Icon(
                    Icons.flight,
                    size: 48,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'GROUND CONTROL STATION',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connect to your drone to begin',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                FilledButton(
                  onPressed: () => context.go('/map'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(220, 56),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
