import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Step indicator dots for multi-step profile creation flows.
class StepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep; // 0-indexed

  const StepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isCurrent = index == currentStep;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: isActive
                ? HearTechColors.deepTeal
                : HearTechColors.paleTeal,
            borderRadius: BorderRadius.circular(5),
            border: !isActive
                ? Border.all(color: HearTechColors.divider)
                : null,
          ),
        );
      }),
    );
  }
}
