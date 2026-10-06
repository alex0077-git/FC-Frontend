import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Browser stand-in for the Digital Sky portal.
///
/// The portal sends `X-Frame-Options: SAMEORIGIN`, so a browser will not draw
/// it inside this app. Showing the frame only produces "refused to connect".
/// The official map opens in a new tab instead. Android and iOS still load it
/// in a WebView, which is not blocked by that rule.
class DigitalSkyHost extends StatefulWidget {
  const DigitalSkyHost({
    super.key,
    required this.portalUrl,
    required this.hidePortalChrome,
    required this.reloadNonce,
    required this.onLoading,
    required this.onLoaded,
    required this.onFailed,
  });

  final String portalUrl;
  final String hidePortalChrome;
  final int reloadNonce;
  final VoidCallback onLoading;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;

  @override
  State<DigitalSkyHost> createState() => _DigitalSkyHostState();
}

class _DigitalSkyHostState extends State<DigitalSkyHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onLoaded();
      }
    });
  }

  void _openPortal() {
    web.window.open(widget.portalUrl, '_blank', 'noopener,noreferrer');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Digital Sky will not open inside this app. Their site blocks other websites from showing the map.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6, color: Color(0xCC000000))],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _openPortal,
              child: const Text('Open Digital Sky'),
            ),
          ],
        ),
      ),
    );
  }
}
