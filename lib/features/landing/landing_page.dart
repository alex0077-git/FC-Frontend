import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _heroAsset = 'assets/images/fuselage_hero.jpeg';
const _logoAsset = 'assets/images/fuselage_logo.jpeg';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10192B), AppTheme.background, Color(0xFF08101C)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _FuselageImage(
              asset: _heroAsset,
              label: 'Fuselage Hero Image',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x9910192B),
                    Color(0xB30B1220),
                    Color(0xE608101C),
                  ],
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _FuselageImage(
                      asset: _logoAsset,
                      label: 'Fuselage Logo',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Fuselage',
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
          ],
        ),
      ),
    );
  }
}

class _FuselageImage extends StatelessWidget {
  const _FuselageImage({
    required this.asset,
    required this.label,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String asset;
  final String label;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return _AssetPlaceholder(label: label, width: width, height: height);
      },
    );
  }
}

class _AssetPlaceholder extends StatelessWidget {
  const _AssetPlaceholder({required this.label, this.width, this.height});

  final String label;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.primary, width: 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
