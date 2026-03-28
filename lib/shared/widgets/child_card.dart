import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';

/// Reusable child summary card for patient lists and dashboards.
class ChildCard extends StatelessWidget {
  final String name;
  final String ageString;
  final String riskLevel;
  final int? riskScore;
  final String? photoUrl;
  final String? lastScreeningDate;
  final VoidCallback? onTap;
  final bool showScore;

  const ChildCard({
    super.key,
    required this.name,
    required this.ageString,
    required this.riskLevel,
    this.riskScore,
    this.photoUrl,
    this.lastScreeningDate,
    this.onTap,
    this.showScore = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HearTechDecorations.cardPadding),
        decoration: HearTechDecorations.cardDecoration,
        child: Row(
          children: [
            AvatarCircle(
              name: name,
              photoUrl: photoUrl,
              radius: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: HearTechTextStyles.subtitle(
                      color: HearTechColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ageString,
                    style: HearTechTextStyles.caption(),
                  ),
                  if (lastScreeningDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Last: $lastScreeningDate',
                      style: HearTechTextStyles.caption(),
                    ),
                  ],
                ],
              ),
            ),
            RiskBadge(
              riskLevel: riskLevel,
              showScore: showScore,
              score: riskScore,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: HearTechColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
