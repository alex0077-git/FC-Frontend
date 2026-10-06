import 'package:fc_frontend/core/widgets/digital_sky_host.dart';
import 'package:flutter/material.dart';

const _portalUrl = 'https://digitalsky.aai.aero/digital-sky-map';

// TODO: Replace these selectors after inspecting the live portal in Chrome.
// Leave the zoom buttons and the Airspace Notice / zone legend visible.
// The map still works if none of these match.
const _hidePortalChrome = '''
header,
nav,
.navbar,
.top-bar,
.site-header,
#header
''';

/// DGCA/AAI Digital Sky map, shown in place of the Flutter map.
class DigitalSkyView extends StatefulWidget {
  const DigitalSkyView({super.key});

  @override
  State<DigitalSkyView> createState() => _DigitalSkyViewState();
}

class _DigitalSkyViewState extends State<DigitalSkyView> {
  var _loading = true;
  var _failed = false;
  var _reloadNonce = 0;

  void _showLoading() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
  }

  void _showLoaded() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _failed = false;
    });
  }

  void _showFailed() {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
      _reloadNonce++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DigitalSkyHost(
          portalUrl: _portalUrl,
          hidePortalChrome: _hidePortalChrome,
          reloadNonce: _reloadNonce,
          onLoading: _showLoading,
          onLoaded: _showLoaded,
          onFailed: _showFailed,
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_failed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digital Sky did not load',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Color(0xCC000000))],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _retry, child: const Text('Retry')),
              ],
            ),
          ),
      ],
    );
  }
}
