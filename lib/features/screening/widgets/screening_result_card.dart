import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'risk_gauge.dart';

class ScreeningResultCard extends StatelessWidget {
  final double riskScore;
  final VoidCallback onActionPressed;
  final bool isHCW;

  const ScreeningResultCard({
    super.key,
    required this.riskScore,
    required this.onActionPressed,
    this.isHCW = false,
  });

  @override
  Widget build(BuildContext context) {
    String message = "Monitor child's hearing. No immediate action needed.";
    String actionText = "RETURN TO DASHBOARD";
    String secondaryMessage = "Regular hearing checks are recommended.";

    if (riskScore >= 0.7) {
      if (isHCW) {
        message = "High risk indicated. Create child profile and refer to audiologist immediately.";
        actionText = "CREATE CHILD PROFILE & REFERRAL";
        secondaryMessage = "Clinical referral workflow will be initiated.";
      } else {
        message = "High risk indicated. Please consult a healthcare professional immediately.";
        actionText = "FIND A CLINIC";
        secondaryMessage = "Early intervention is key.";
      }
    } else if (riskScore >= 0.3) {
      if (isHCW) {
        message = "Medium risk indicated. Schedule a follow-up or formal test.";
        actionText = "CREATE CHILD PROFILE";
        secondaryMessage = "Monitor closely for the next 3 months.";
      } else {
        message = "Elevated risk detected. We recommend discussing this with a doctor.";
        actionText = "VIEW GUIDANCE";
        secondaryMessage = "You can share this result with your pediatrician.";
      }
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.dividerColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            RiskGauge(riskScore: riskScore),
            const SizedBox(height: 32),
            Text(
              message,
              style: AppTheme.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              secondaryMessage,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onActionPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(actionText, style: AppTheme.buttonText.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
