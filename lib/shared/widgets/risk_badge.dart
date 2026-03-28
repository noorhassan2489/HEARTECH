import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Risk badge pill — Green for Low, Orange for Medium, Red for High.
class RiskBadge extends StatelessWidget {
  final String riskLevel;
  final bool showScore;
  final int? score;
  final bool large;

  const RiskBadge({
    super.key,
    required this.riskLevel,
    this.showScore = false,
    this.score,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = HearTechColors.riskColor(riskLevel);
    final label = riskLevel[0].toUpperCase() + riskLevel.substring(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: HearTechDecorations.badgeBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 10 : 8,
            height: large ? 10 : 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            showScore && score != null ? '$label ($score)' : '$label Risk',
            style: HearTechTextStyles.label(color: color).copyWith(
              fontSize: large ? 14 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
