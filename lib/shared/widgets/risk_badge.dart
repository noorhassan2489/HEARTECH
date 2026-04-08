import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Risk badge pill — solid colour background with white text.
/// Green "Low Risk", Orange "Medium Risk", Red "High Risk".
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
    final capitalised =
        riskLevel.isEmpty ? '' : riskLevel[0].toUpperCase() + riskLevel.substring(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: HearTechDecorations.badgeBorderRadius,
      ),
      child: Text(
        showScore && score != null ? '$capitalised ($score)' : '$capitalised Risk',
        style: GoogleFonts.nunito(
          fontSize: large ? 14 : 13,
          fontWeight: FontWeight.w700,
          color: HearTechColors.white,
        ),
      ),
    );
  }
}
