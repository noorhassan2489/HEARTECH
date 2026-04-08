import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Input field with icon, floating label, error text, and password toggle.
class HearTechInputField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscureText;
  final String? errorText;
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
    this.errorText,
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
  State<HearTechInputField> createState() => _HearTechInputFieldState();
}

class _HearTechInputFieldState extends State<HearTechInputField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          onChanged: widget.onChanged,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          maxLength: widget.maxLength,
          enabled: widget.enabled,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: HearTechTextStyles.body(),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: HearTechColors.deepTeal)
                : null,
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: HearTechColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscured = !_obscured;
                      });
                    },
                  )
                : widget.suffix,
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
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: HearTechDecorations.inputBorderRadius,
              borderSide: const BorderSide(
                color: HearTechColors.coralRed,
                width: 1.5,
              ),
            ),
            floatingLabelStyle:
                HearTechTextStyles.caption(color: HearTechColors.deepTeal),
          ),
        ),
        // External error text (from API validation, etc.)
        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              widget.errorText!,
              style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                  .copyWith(fontWeight: FontWeight.w400),
            ),
          ),
      ],
    );
  }
}
