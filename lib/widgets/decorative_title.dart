import 'package:flutter/material.dart';

class DecorativeTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;

  const DecorativeTitle(
    this.text, {
    super.key,
    this.fontSize = 34,
    this.color = const Color(0xFFE53935),
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: 0.5,
    );

    return Stack(
      children: [
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white,
          ),
        ),
        Text(text, style: style.copyWith(color: color)),
      ],
    );
  }
}
