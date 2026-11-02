import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the original CALCULATOR2.html (bundled as a Flutter asset)
/// inside a WebView -- same approach as the original Kodular screen
/// (WebViewer showing CALCULATOR2.html), just rebuilt natively in
/// Flutter. The HTML/JS itself is untouched, including its own Firebase
/// read for product prices.
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

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

    // Same disclaimer the original screen showed as a native overlay
    // (Vertical_Arrangement1 + "Yes I Know" button) before the calculator
    // itself was usable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclaimer());
  }

  Future<void> _showDisclaimer() async {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order / POB Calculator')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
