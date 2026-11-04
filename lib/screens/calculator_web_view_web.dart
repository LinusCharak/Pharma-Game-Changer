import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class CalculatorWebView extends StatelessWidget {
  const CalculatorWebView({super.key});

  static bool _registered = false;

  static void _registerView() {
    if (_registered) return;

    ui_web.platformViewRegistry.registerViewFactory(
      'calculator-html-view',
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = Uri.base.resolve(
            'assets/assets/html/CALCULATOR2.html',
          ).toString()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'block'
          ..setAttribute('allow', 'clipboard-read; clipboard-write');

        return iframe;
      },
    );

    _registered = true;
  }

  @override
  Widget build(BuildContext context) {
    _registerView();

    return const HtmlElementView(
      viewType: 'calculator-html-view',
    );
  }
}
