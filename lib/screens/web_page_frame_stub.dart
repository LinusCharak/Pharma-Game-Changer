import 'package:flutter/material.dart';

/// Android / iOS: not used (the WebView is used there).
class WebPageFrame extends StatelessWidget {
  final String url;

  const WebPageFrame({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Android / iOS: not used.
void openUrlInNewTab(String url) {}
