import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isVendo = type == 'Vendo';
    final bg = isVendo ? AppColors.greenBg : AppColors.blueBg;
    final fg = isVendo ? const Color(0xFF15803D) : const Color(0xFF1D4ED8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(type, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}