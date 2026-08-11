import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final double titleSize;

  const SectionHeader({super.key, required this.title, required this.subtitle, this.titleSize = 28});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.textGrey)),
      ],
    );
  }
}