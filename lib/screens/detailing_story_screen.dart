import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DetailingStoryScreen extends StatefulWidget {
  const DetailingStoryScreen({super.key});

  @override
  State<DetailingStoryScreen> createState() => _DetailingStoryScreenState();
}

class _DetailingStoryScreenState extends State<DetailingStoryScreen> {
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

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
      ..loadFlutterAsset('assets/html/DETAILINGSTORY.html');
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    _controller.loadFlutterAsset('assets/html/DETAILINGSTORY.html');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detailing Story'),
      ),
      body: Stack(
        children: [
          if (!_hasError)
            WebViewWidget(
              controller: _controller,
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