import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'product_html_frame_stub.dart'
    if (dart.library.html) 'product_html_frame_web.dart';

const String _detailingStoryAsset = 'assets/html/DETAILINGSTORY.html';

class DetailingStoryScreen extends StatefulWidget {
  const DetailingStoryScreen({super.key});

  @override
  State<DetailingStoryScreen> createState() => _DetailingStoryScreenState();
}

class _DetailingStoryScreenState extends State<DetailingStoryScreen> {
  // Not created on the web: webview_flutter has no web implementation
  // (the iframe in ProductHtmlFrame is used there instead).
  WebViewController? _controller;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadFlutterAsset(_detailingStoryAsset);
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _controller?.loadFlutterAsset(_detailingStoryAsset);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detailing Story'),
        ),
        body: const ProductHtmlFrame(assetPath: _detailingStoryAsset),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailing Story'),
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(
              controller: _controller!,
            ),

          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(),
            ),

          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load Detailing Story.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
