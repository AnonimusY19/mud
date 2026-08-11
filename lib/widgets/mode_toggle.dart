import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_colors.dart';

class ModeToggle extends StatelessWidget {
  final AppMode mode;
  final ValueChanged<AppMode> onChanged;

  const ModeToggle({super.key, required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceGrey,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'Compra', AppMode.compra),
          _segment(context, 'Vendi', AppMode.vendi),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, AppMode value) {
    final selected = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: selected ? AppColors.primary : AppColors.textLightGrey,
          ),
        ),
      ),
    );
  }
}