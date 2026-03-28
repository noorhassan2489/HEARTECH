import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Primary and secondary button with HearTech styling.
/// Full width, height 56, rounded 16, with optional loading state.
class HearTechButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const HearTechButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isSecondary) {
      return SizedBox(
        width: double.infinity,
        height: HearTechDecorations.buttonHeight,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor ?? HearTechColors.deepTeal,
            side: BorderSide(
              color: textColor ?? HearTechColors.deepTeal,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: HearTechDecorations.buttonBorderRadius,
            ),
          ),
          child: _buildChild(textColor ?? HearTechColors.deepTeal),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: HearTechDecorations.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? HearTechColors.deepTeal,
          foregroundColor: textColor ?? HearTechColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: HearTechDecorations.buttonBorderRadius,
          ),
          elevation: 0,
        ),
        child: _buildChild(textColor ?? HearTechColors.white),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label, style: HearTechTextStyles.button(color: color)),
        ],
      );
    }

    return Text(label, style: HearTechTextStyles.button(color: color));
  }
}
