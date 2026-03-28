import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Input field with icon, floating label, error state, and optional suffix.
class HearTechInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  const HearTechInputField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: HearTechTextStyles.body(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: HearTechColors.deepTeal)
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: HearTechColors.paleTeal,
        border: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: const BorderSide(
            color: HearTechColors.deepTeal,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: const BorderSide(
            color: HearTechColors.coralRed,
            width: 1.5,
          ),
        ),
        floatingLabelStyle:
            HearTechTextStyles.caption(color: HearTechColors.deepTeal),
      ),
    );
  }
}
