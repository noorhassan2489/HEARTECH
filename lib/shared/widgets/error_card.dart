import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

/// Error card with red icon, message, and retry button.
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(HearTechDecorations.screenPadding),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          borderRadius: HearTechDecorations.cardBorderRadius,
          boxShadow: HearTechDecorations.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: HearTechColors.coralRed),
            const SizedBox(height: 16),
            Text(
              message,
              style: HearTechTextStyles.body(
                color: HearTechColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              HearTechButton(
                label: 'Retry',
                onPressed: onRetry,
                icon: Icons.refresh,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
