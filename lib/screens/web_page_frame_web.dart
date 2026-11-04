import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Chrome / web: shows a web page (an https address) inside an iframe,
/// because webview_flutter has no web implementation.
///
/// Note: a website can forbid being shown inside another page. If that
/// happens the frame stays empty -- use [openUrlInNewTab] as the fallback.
class WebPageFrame extends StatelessWidget {
  final String url;

  const WebPageFrame({super.key, required this.url});

  static final Set<String> _registered = <String>{};

  static String _viewType(String url) => 'web-page-$url';

  static void _registerView(String url) {
    final viewType = _viewType(url);
    if (_registered.contains(viewType)) return;

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = url
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block'
          ..setAttribute('allow', 'clipboard-read; clipboard-write');

        return iframe;
      },
    );

    _registered.add(viewType);
  }

  @override
  Widget build(BuildContext context) {
    _registerView(url);

    return HtmlElementView(viewType: _viewType(url));
  }
}

/// Opens [url] in a new browser tab.
void openUrlInNewTab(String url) {
  html.window.open(url, '_blank');
}
