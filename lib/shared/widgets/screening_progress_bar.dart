import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Animated linear progress bar with teal fill for screening steps.
/// Shows "Question X of Y" label above the bar.
class ScreeningProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const ScreeningProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? current / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question $current of $total',
          style: HearTechTextStyles.caption().copyWith(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: HearTechColors.paleTeal,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  HearTechColors.deepTeal,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
