import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Widget formLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary)),
  );
}

Widget formTextField({
  required TextEditingController controller,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  bool obscureText = false,
  bool readOnly = false,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.border),
  );
  return TextField(
    controller: controller,
    maxLines: obscureText ? 1 : maxLines,
    keyboardType: keyboardType,
    obscureText: obscureText,
    readOnly: readOnly,
    enableInteractiveSelection: !readOnly,
    style: const TextStyle(color: AppColors.textPrimary),
    cursorColor: AppColors.primary,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textLightGrey),
      filled: true,
      fillColor: readOnly ? AppColors.surface : AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: readOnly
          ? border
          : border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      suffixIcon: suffixIcon,
    ),
  );
}
