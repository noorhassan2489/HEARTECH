import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Generic stat card with icon, large number, and label.
class SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? iconColor;

  const SummaryCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(HearTechDecorations.cardPadding),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: iconColor ?? HearTechColors.deepTeal,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: HearTechTextStyles.screenTitle(
              color: HearTechColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: HearTechTextStyles.caption(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
