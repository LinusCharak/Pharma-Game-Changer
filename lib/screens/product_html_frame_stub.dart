import 'package:flutter/material.dart';

/// Android / iOS: not used (the WebView in product_html_screen.dart is used).
class ProductHtmlFrame extends StatelessWidget {
  final String assetPath;

  const ProductHtmlFrame({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
