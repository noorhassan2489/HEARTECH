import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

/// Empty state card — centered icon/image + message + optional action button.
class EmptyStateCard extends StatelessWidget {
  final IconData? icon;
  final String? imagePath;
  final String? message;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;

  /// Legacy params — use [message] instead of [title]/[subtitle],
  /// and [onButtonTap] instead of [onButtonPressed].
  final String? title;
  final String? subtitle;
  final VoidCallback? onButtonPressed;

  const EmptyStateCard({
    super.key,
    this.icon,
    this.imagePath,
    this.message,
    this.buttonLabel,
    this.onButtonTap,
    this.title,
    this.subtitle,
    this.onButtonPressed,
  });

  String get _displayMessage =>
      message ?? [title, subtitle].where((s) => s != null).join('\n');

  VoidCallback? get _resolvedOnTap => onButtonTap ?? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image or icon
            if (imagePath != null)
              Image.asset(
                imagePath!,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildIconFallback(),
              )
            else
              _buildIconFallback(),
            const SizedBox(height: 24),
            Text(
              _displayMessage,
              style: HearTechTextStyles.body(
                color: HearTechColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && _resolvedOnTap != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: HearTechButton(
                  label: buttonLabel!,
                  onPressed: _resolvedOnTap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconFallback() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: HearTechColors.paleTeal,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.inbox_outlined,
        size: 56,
        color: HearTechColors.deepTeal.withValues(alpha: 0.6),
      ),
    );
  }
}
