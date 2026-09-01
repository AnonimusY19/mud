import 'package:flutter/material.dart';

/// Palette MUD: brand fissi + superfici/testi dipendenti dal tema.
class AppColors {
  AppColors._();

  static bool _isDark = true;

  static bool get isDark => _isDark;

  static void applyBrightness(Brightness brightness) {
    _isDark = brightness == Brightness.dark;
  }

  // Brand / status (invariati tra temi)
  static const primary = Color(0xFF1266F1);
  static const primaryDark = Color(0xFF0E4FC4);

  static const green = Color(0xFF22C55E);
  static const blue = Color(0xFF60A5FA);
  static const danger = Color(0xFFEF4444);

  static Color get background =>
      _isDark ? const Color(0xFF0A1628) : const Color(0xFFF4F7FB);

  static Color get surface =>
      _isDark ? const Color(0xFF122033) : const Color(0xFFFFFFFF);

  static Color get surfaceElevated =>
      _isDark ? const Color(0xFF1A2B42) : const Color(0xFFEEF2F7);

  static Color get greenBg =>
      _isDark ? const Color(0xFF143528) : const Color(0xFFDCFCE7);

  static Color get blueBg =>
      _isDark ? const Color(0xFF152A4A) : const Color(0xFFDBEAFE);

  static Color get border =>
      _isDark ? const Color(0xFF2A3B55) : const Color(0xFFD5DEE8);

  static Color get surfaceGrey =>
      _isDark ? const Color(0xFF1A2B42) : const Color(0xFFE8EDF3);

  static Color get textPrimary =>
      _isDark ? const Color(0xFFF3F6FB) : const Color(0xFF0F1B2D);

  static Color get textGrey =>
      _isDark ? const Color(0xFF9CA8BC) : const Color(0xFF5B6B7F);

  static Color get textLightGrey =>
      _isDark ? const Color(0xFF7A879C) : const Color(0xFF8090A3);

  static LinearGradient get brandGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _isDark
            ? const [
                Color(0xFF0A1628),
                Color(0xFF0E4FC4),
                Color(0xFF1266F1),
              ]
            : const [
                Color(0xFFE8F0FE),
                Color(0xFF9DBCF7),
                Color(0xFF1266F1),
              ],
      );
}
