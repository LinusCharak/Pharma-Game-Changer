import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/promotogram_service.dart';

/// Replaces the Promotogram screen: fetches a URL from Firebase (see
/// PromotogramService), then loads that URL in a WebView. The page shown
/// is entirely controlled from Firebase/GitHub Pages -- nothing about
/// which page loads is hardcoded here, matching the original design.
class PromotogramScreen extends StatefulWidget {
  const PromotogramScreen({super.key});

  @override
  State<PromotogramScreen> createState() => _PromotogramScreenState();
}

class _PromotogramScreenState extends State<PromotogramScreen> {
  final _service = PromotogramService();
  WebViewController? _controller;
  bool _pageLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _controller = null;
    });

    try {
      final url = await _service.fetchUrl();
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _pageLoading = false);
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _pageLoading = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load Promotogram.\n$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Promotogram')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    WebViewWidget(controller: _controller!),
                    if (_pageLoading) const Center(child: CircularProgressIndicator()),
                  ],
                ),
    );
  }
}
