import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

Widget formLabel(String text, {bool compact = false}) {
  return Padding(
    padding: EdgeInsets.only(bottom: compact ? 4 : 8),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: compact ? 12.5 : 14,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

Widget formTextField({
  required TextEditingController controller,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  bool obscureText = false,
  bool readOnly = false,
  bool dense = false,
  Widget? suffixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: AppColors.border),
  );
  return TextField(
    controller: controller,
    maxLines: obscureText ? 1 : maxLines,
    keyboardType: keyboardType,
    obscureText: obscureText,
    readOnly: readOnly,
    enableInteractiveSelection: !readOnly,
    style: TextStyle(color: AppColors.textPrimary, fontSize: dense ? 14 : 15),
    cursorColor: AppColors.primary,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textLightGrey),
      filled: true,
      fillColor: readOnly ? AppColors.surface : AppColors.surfaceElevated,
      isDense: dense,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 10 : 12),
      border: border,
      enabledBorder: border,
      focusedBorder: readOnly
          ? border
          : border.copyWith(borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      suffixIcon: suffixIcon,
    ),
  );
}
