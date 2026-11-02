import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/product_html_routes.dart';

/// Generic viewer for any product's bundled HTML page. One screen for
/// every product -- which file loads is resolved purely from
/// [startValue] via productHtmlFiles, so adding a new product never
/// requires a new Flutter screen.
class ProductHtmlScreen extends StatefulWidget {
  final String startValue;
  final String? title;

  const ProductHtmlScreen({
    super.key,
    required this.startValue,
    this.title,
  });

  @override
  State<ProductHtmlScreen> createState() => _ProductHtmlScreenState();
}

class _ProductHtmlScreenState extends State<ProductHtmlScreen> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    final assetPath = productHtmlFiles[widget.startValue];
    if (assetPath == null) {
      // No HTML mapped for this startValue yet -- handled entirely in
      // build() below. No WebViewController is created, so there is
      // nothing that could crash or show a blank WebView.
      return;
    }

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
      ..loadFlutterAsset(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? widget.startValue)),
      body: controller == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Content not available yet.\n'
                  'HTML content for "${widget.startValue}" is not available yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: controller),
                if (_loading) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
