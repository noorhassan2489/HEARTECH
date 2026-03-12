import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'risk_badge.dart';

class ChildCard extends StatelessWidget {
  final String childId;
  final String name;
  final int ageMonths;
  final String riskLevel;
  final VoidCallback onTap;

  const ChildCard({
    super.key,
    required this.childId,
    required this.name,
    required this.ageMonths,
    required this.riskLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryPale,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: AppTheme.heading2.copyWith(color: AppTheme.primaryTeal),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.heading2),
                  const SizedBox(height: 4),
                  Text("$ageMonths months old", style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            RiskBadge(riskLevel: riskLevel),
          ],
        ),
      ),
    );
  }
}
