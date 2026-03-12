import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 24 : 12,
          height: 12,
          decoration: BoxDecoration(
            color: isCompleted || isCurrent
                ? AppTheme.primaryTeal
                : AppTheme.dividerColor,
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
