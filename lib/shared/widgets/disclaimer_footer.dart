import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/constants/app_constants.dart';

/// Disclaimer footer shown on every screening result screen.
class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: HearTechColors.warmOrange.withValues(alpha: 0.08),
        borderRadius: HearTechDecorations.cardBorderRadius,
        border: Border.all(
          color: HearTechColors.warmOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: HearTechColors.warmOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppConstants.disclaimer,
              style: HearTechTextStyles.caption(
                color: HearTechColors.warmOrange,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
