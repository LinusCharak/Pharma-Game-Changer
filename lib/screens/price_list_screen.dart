import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/price_list_service.dart';
import 'web_page_frame_stub.dart'
    if (dart.library.html) 'web_page_frame_web.dart';

/// Replaces the Price_List screen: fetches a URL from Firebase (see PriceListService), then shows that URL. Which page shows is controlled from Firebase, not hardcoded here.
///
/// Android / iOS: WebView. Chrome (web): iframe, because webview_flutter
/// has no web implementation. On the web an "open in new tab" button is
/// also shown, in case the website does not allow being shown in a frame.
class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> {
  final _service = PriceListService();
  WebViewController? _controller;
  String? _webUrl; // web only
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
      _webUrl = null;
    });

    try {
      final url = await _service.fetchUrl();

      if (kIsWeb) {
        // No WebViewController on the web -- the iframe shows the page.
        if (!mounted) return;
        setState(() => _webUrl = url);
        return;
      }

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
    final webUrl = _webUrl;

    Widget body;
    if (_error != null) {
      body = Center(
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
      );
    } else if (kIsWeb) {
      body = webUrl == null
          ? const Center(child: CircularProgressIndicator())
          : WebPageFrame(url: webUrl);
    } else if (_controller == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = Stack(
        children: [
          WebViewWidget(controller: _controller!),
          if (_pageLoading) const Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price List (MRP)'),
        actions: [
          if (kIsWeb && webUrl != null)
            IconButton(
              tooltip: 'Open in new tab',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openUrlInNewTab(webUrl),
            ),
        ],
      ),
      body: body,
    );
  }
}
