import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Chrome / web: shows a bundled HTML asset (for example
/// 'assets/html/PLAT_C.html') inside an iframe, because webview_flutter
/// has no web implementation. Same approach as calculator_web_view_web.dart.
class ProductHtmlFrame extends StatelessWidget {
  final String assetPath;

  const ProductHtmlFrame({super.key, required this.assetPath});

  static final Set<String> _registered = <String>{};

  static String _viewType(String assetPath) => 'product-html-$assetPath';

  static void _registerView(String assetPath) {
    final viewType = _viewType(assetPath);
    if (_registered.contains(viewType)) return;

    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        // Flutter web serves bundled assets under /assets/, so an asset
        // declared as 'assets/html/X.html' is at 'assets/assets/html/X.html'.
        final iframe = html.IFrameElement()
          ..src = Uri.base.resolve('assets/$assetPath').toString()
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
    _registerView(assetPath);

    return HtmlElementView(viewType: _viewType(assetPath));
  }
}
