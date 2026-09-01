import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

ThemeData buildMudTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final background = isDark ? const Color(0xFF0A1628) : const Color(0xFFF4F7FB);
  final surface = isDark ? const Color(0xFF122033) : const Color(0xFFFFFFFF);
  final surfaceElevated = isDark ? const Color(0xFF1A2B42) : const Color(0xFFEEF2F7);
  final border = isDark ? const Color(0xFF2A3B55) : const Color(0xFFD5DEE8);
  final textPrimary = isDark ? const Color(0xFFF3F6FB) : const Color(0xFF0F1B2D);
  final textGrey = isDark ? const Color(0xFF9CA8BC) : const Color(0xFF5B6B7F);
  final textLightGrey = isDark ? const Color(0xFF7A879C) : const Color(0xFF8090A3);

  final scheme = isDark
      ? ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.primaryDark,
          surface: surface,
          error: AppColors.danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        )
      : ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primaryDark,
          surface: surface,
          error: AppColors.danger,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textPrimary,
          onError: Colors.white,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: surface,
    dividerColor: border,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      systemOverlayStyle: isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: surface),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surfaceElevated,
      contentTextStyle: TextStyle(color: textPrimary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceElevated,
      hintStyle: TextStyle(color: textLightGrey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        return textGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return border;
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    iconTheme: IconThemeData(color: textGrey),
    listTileTheme: ListTileThemeData(
      iconColor: textGrey,
      textColor: textPrimary,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textPrimary),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
    ),
  );
}

void syncSystemUiOverlay(ThemeMode mode) {
  final isDark = mode != ThemeMode.light;
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor:
          isDark ? const Color(0xFF0A1628) : const Color(0xFFF4F7FB),
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ),
  );
}
