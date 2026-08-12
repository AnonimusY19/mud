import 'package:flutter/material.dart';

/// Palette scura allineata alla schermata auth (navy + blu MUD).
class AppColors {
  AppColors._();

  static const primary = Color(0xFF1266F1);
  static const primaryDark = Color(0xFF0E4FC4);

  static const background = Color(0xFF0A1628);
  static const surface = Color(0xFF122033);
  static const surfaceElevated = Color(0xFF1A2B42);

  static const green = Color(0xFF22C55E);
  static const greenBg = Color(0xFF143528);

  static const blue = Color(0xFF60A5FA);
  static const blueBg = Color(0xFF152A4A);

  static const border = Color(0xFF2A3B55);
  static const surfaceGrey = Color(0xFF1A2B42);

  static const textPrimary = Color(0xFFF3F6FB);
  static const textGrey = Color(0xFF9CA8BC);
  static const textLightGrey = Color(0xFF7A879C);

  static const danger = Color(0xFFEF4444);

  /// Gradiente branding (auth / hero).
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A1628),
      Color(0xFF0E4FC4),
      Color(0xFF1266F1),
    ],
  );
}
