import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Button variant enum for HearTech buttons.
enum HearTechButtonVariant { primary, secondary, destructive }

/// Primary, secondary, and destructive button with HearTech styling.
/// Full width, height 56, rounded 16, with optional loading state and icon.
class HearTechButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final HearTechButtonVariant variant;
  final IconData? icon;

  /// Legacy parameter — use [variant] instead.
  final bool isSecondary;

  /// Optional custom background color (only applies to primary variant).
  final Color? backgroundColor;

  /// Optional custom text/icon color override.
  final Color? textColor;

  const HearTechButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.variant = HearTechButtonVariant.primary,
    this.icon,
    this.isSecondary = false,
    this.backgroundColor,
    this.textColor,
  });

  /// Convenience constructor for secondary buttons.
  const HearTechButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.textColor,
  })  : variant = HearTechButtonVariant.secondary,
        isSecondary = false,
        backgroundColor = null;

  /// Convenience constructor for destructive buttons.
  const HearTechButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.textColor,
  })  : variant = HearTechButtonVariant.destructive,
        isSecondary = false,
        backgroundColor = null;

  /// Resolved variant — isSecondary overrides if true.
  HearTechButtonVariant get _resolvedVariant =>
      isSecondary ? HearTechButtonVariant.secondary : variant;

  bool get _isDisabled => onPressed == null && !isLoading;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _isDisabled ? 0.5 : 1.0,
      child: SizedBox(
        width: double.infinity,
        height: HearTechDecorations.buttonHeight,
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    switch (_resolvedVariant) {
      case HearTechButtonVariant.primary:
        final bg = backgroundColor ?? HearTechColors.deepTeal;
        final fg = textColor ?? HearTechColors.white;
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg,
            disabledForegroundColor: fg,
            shape: RoundedRectangleBorder(
              borderRadius: HearTechDecorations.buttonBorderRadius,
            ),
            elevation: 0,
          ),
          child: _buildChild(fg),
        );
      case HearTechButtonVariant.secondary:
        final fg = textColor ?? HearTechColors.deepTeal;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: HearTechDecorations.buttonBorderRadius,
            ),
          ),
          child: _buildChild(fg),
        );
      case HearTechButtonVariant.destructive:
        final fg = textColor ?? HearTechColors.coralRed;
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: fg,
            side: BorderSide(color: fg, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: HearTechDecorations.buttonBorderRadius,
            ),
          ),
          child: _buildChild(fg),
        );
    }
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
