import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isVendo = type == 'Vendo';
    final bg = isVendo ? AppColors.greenBg : AppColors.blueBg;
    final fg = isVendo ? AppColors.green : AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(type, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
