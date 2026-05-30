import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final bool isPassword;
  final bool darkTheme;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText; // NEW: Allows adding fixed text like "+20"

  const CustomTextField({
    super.key,
    required this.hintText,
    this.isPassword = false,
    this.darkTheme = false,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText, // NEW
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: TextStyle(
        color: darkTheme ? AppColors.white : AppColors.navy,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: darkTheme ? Colors.white54 : AppColors.greyText,
          fontSize: 14,
        ),
        // NEW: Displays the "+20" visually inside the box
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: darkTheme ? AppColors.white : AppColors.navy,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: darkTheme ? const Color(0xFF1E293B) : AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: darkTheme
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: darkTheme
              ? BorderSide.none
              : const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}