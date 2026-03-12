import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RiskBadge extends StatelessWidget {
  final String riskLevel; // "Low", "Medium", "High"

  const RiskBadge({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (riskLevel.toLowerCase()) {
      case 'low':
        badgeColor = AppTheme.safeGreen;
        break;
      case 'medium':
        badgeColor = Colors.orange;
        break;
      case 'high':
        badgeColor = AppTheme.accentCoral;
        break;
      default:
        badgeColor = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        riskLevel,
        style: AppTheme.caption.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
