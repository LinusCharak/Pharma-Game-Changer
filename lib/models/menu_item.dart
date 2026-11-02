import 'package:flutter/widgets.dart';

class MenuFeature {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final WidgetBuilder screenBuilder;

  const MenuFeature({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.screenBuilder,
  });
}
