import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Responsive row of handover-code character boxes (scales on narrow screens).
class HandoverCodeBoxes extends StatelessWidget {
  final String code;
  final bool animate;

  const HandoverCodeBoxes({
    super.key,
    required this.code,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxBoxWidth = 44.0;
        const maxBoxHeight = 56.0;
        const minBoxWidth = 34.0;
        const gap = 6.0;
        final count = code.length;

        final available = constraints.maxWidth;
        final fitWidth = count > 0
            ? (available - gap * (count - 1)) / count
            : maxBoxWidth;
        final boxWidth = fitWidth.clamp(minBoxWidth, maxBoxWidth);
        final boxHeight = boxWidth * (maxBoxHeight / maxBoxWidth);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) SizedBox(width: gap),
              _buildBox(code[i], boxWidth, boxHeight, i),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBox(String char, double width, double height, int index) {
    Widget box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(char, style: HearTechTextStyles.handoverCode()),
        ),
      ),
    );

    if (animate) {
      box = box.animate(delay: (index * 80).ms).scale(
        begin: const Offset(0, 0),
        end: const Offset(1, 1),
        duration: 300.ms,
        curve: Curves.elasticOut,
      );
    }

    return box;
  }
}
