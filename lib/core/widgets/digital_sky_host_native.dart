import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android and iOS Digital Sky portal.
///
/// The system back button is not handled here, so it leaves the screen
/// instead of stepping back through the portal's own history.
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
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => widget.onLoading(),
          onPageFinished: (_) {
            widget.onLoaded();
            _hideChrome();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) {
              return;
            }
            widget.onFailed();
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.portalUrl));
  }

  @override
  void didUpdateWidget(DigitalSkyHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadNonce != oldWidget.reloadNonce) {
      _controller.loadRequest(Uri.parse(widget.portalUrl));
    }
  }

  Future<void> _hideChrome() async {
    final css = jsonEncode(
      '${widget.hidePortalChrome} { display: none !important; }',
    );
    final script =
        '''
(function () {
  try {
    var style = document.createElement('style');
    style.setAttribute('data-fc-hide-chrome', '1');
    style.textContent = $css;
    (document.head || document.documentElement).appendChild(style);
  } catch (e) {}
})();
''';
    try {
      await _controller.runJavaScript(script);
    } catch (_) {
      // Hiding the portal header is optional. The map still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
      },
    );
  }
}
