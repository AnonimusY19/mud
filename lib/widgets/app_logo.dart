import 'package:flutter/material.dart';

/// Logo applicazione MUD (asset locale, bordi arrotondati).
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppLogo({
    super.key,
    this.size = 36,
    this.borderRadius = 10,
  });

  static const assetPath = 'assets/images/app_logo.jpg';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
