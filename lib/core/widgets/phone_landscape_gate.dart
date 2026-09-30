import 'package:flutter/material.dart';

class PhoneLandscapeGate extends StatelessWidget {
  const PhoneLandscapeGate({super.key, required this.child});

  final Widget child;

  static const phoneShortestSide = 600.0;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final phoneInPortrait =
        size.shortestSide < phoneShortestSide && size.height > size.width;
    if (!phoneInPortrait) {
      return child;
    }
    return const _RotateToLandscape();
  }
}

class _RotateToLandscape extends StatelessWidget {
  const _RotateToLandscape();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.screen_rotation, size: 56, color: scheme.primary),
              const SizedBox(height: 20),
              Text(
                'Rotate to landscape',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'The phone uses the same layout as a laptop.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
