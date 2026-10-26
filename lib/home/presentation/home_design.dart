import 'package:flutter/material.dart';

/// Colors and typography read from the Figma Home frame (18:2).
abstract final class HomeDesign {
  static const red = Color(0xFFC10E3D);
  static const palePink = Color(0xFFFBE5EB);
  static const pink = Color(0xFFF3B9C9);
  static const muted = Color(0xFF806D78);
  static const ink = Color(0xFF382331);

  static TextStyle text(
    double size, {
    Color color = red,
    FontWeight weight = FontWeight.w800,
    double height = 1.333333,
  }) => TextStyle(
    fontFamily: 'NunitoSans',
    fontSize: size,
    height: height,
    fontWeight: weight,
    color: color,
    fontVariations: [
      FontVariation('wght', weight.value.toDouble()),
      const FontVariation('YTLC', 500),
      const FontVariation('wdth', 100),
      const FontVariation('opsz', 12),
    ],
  );
}
