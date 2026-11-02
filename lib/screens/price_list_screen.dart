import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/price_list_service.dart';

/// Replaces the Price_List screen: fetches a URL from Firebase (see
/// PriceListService), then loads that URL in a WebView. Which page shows
/// is entirely controlled from Firebase, not hardcoded here -- same
/// design as the original.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  final _service = PriceListService();
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
      setState(() => _error = "Couldn't load Price List.\n$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Price List (MRP)')),
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
