import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/product_html_routes.dart';
import 'product_html_frame_stub.dart'
    if (dart.library.html) 'product_html_frame_web.dart';

/// Generic viewer for any product's bundled HTML page. One screen for
/// every product -- which file loads is resolved purely from
/// [startValue] via productHtmlFiles, so adding a new product never
/// requires a new Flutter screen.
///
/// Android / iOS: WebView. Chrome (web): iframe, because webview_flutter
/// has no web implementation.
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

    // On the web the iframe is used instead; creating a WebViewController
    // there would throw "A platform implementation for webview_flutter
    // has not been set".
    if (kIsWeb) return;

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
    final assetPath = productHtmlFiles[widget.startValue];
    final controller = _controller;

    Widget body;
    if (assetPath == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Content not available yet.\n'
            'HTML content for "${widget.startValue}" is not available yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (kIsWeb) {
      body = ProductHtmlFrame(assetPath: assetPath);
    } else {
      body = Stack(
        children: [
          WebViewWidget(controller: controller!),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? widget.startValue)),
      body: body,
    );
  }
}
