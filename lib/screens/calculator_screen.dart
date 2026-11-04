import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'calculator_web_view_stub.dart'
    if (dart.library.html) 'calculator_web_view_web.dart';

/// Hosts the original CALCULATOR2.html (bundled as a Flutter asset).
/// On Android/iOS it runs inside a WebView; on web (Chrome) it runs inside
/// an iframe, because webview_flutter has no web implementation.
/// The HTML/JS itself is untouched, including its own Firebase
/// read for product prices.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  WebViewController? _controller;
  bool _loading = true;
  // On web the calculator iframe would sit on top of the popup and block
  // its button, so it is only added after the disclaimer is accepted.
  bool _accepted = !kIsWeb;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _loading = false;
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
          ),
        )
        ..loadFlutterAsset('assets/html/CALCULATOR2.html');
    }

    // Same disclaimer the original screen showed as a native overlay
    // (Vertical_Arrangement1 + "Yes I Know" button) before the calculator
    // itself was usable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  Future<void> _showDisclaimer() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('WARNING'),
        content: const Text(
          'Calculation is based on Trade Price.\n\n'
          'Trade Price may vary depending on many factors. Therefore these '
          'values should not be considered as accurate and official values. '
          'These are approximate values only.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Yes I Know'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _accepted = true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Order / POB Calculator')),
      body: Stack(
        children: [
          if (kIsWeb)
            (_accepted ? const CalculatorWebView() : const SizedBox.shrink())
          else if (controller != null)
            WebViewWidget(controller: controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
