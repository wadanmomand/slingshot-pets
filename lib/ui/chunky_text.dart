// Chunky golden 3D bubble text (locked design language).
// Home-screen style: huge, bold, golden gradient, white outline,
// dark-brown outer stroke.
import 'package:flutter/material.dart';

class ChunkyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double letterSpacing;

  const ChunkyText(
    this.text, {
    super.key,
    this.fontSize = 72,
    this.letterSpacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          // Dark-brown outer stroke.
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.22
                ..strokeJoin = StrokeJoin.round
                ..color = const Color(0xFF5D3A1A),
            ),
          ),
          // Thick white outline.
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.13
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
            ),
          ),
          // Golden gradient fill with bottom shade for 3D depth.
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: letterSpacing,
              foreground: Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFF3C4),
                    Color(0xFFFFD54F),
                    Color(0xFFFFB300),
                    Color(0xFFF57C00),
                  ],
                  stops: [0.0, 0.35, 0.7, 1.0],
                ).createShader(
                    Rect.fromLTWH(0, 0, 400, fontSize * 1.2)),
              shadows: const [
                Shadow(
                    color: Color(0xFFB26A00),
                    offset: Offset(0, 5),
                    blurRadius: 0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
