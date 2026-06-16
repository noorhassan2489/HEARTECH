import 'package:flutter/material.dart';
import 'package:heartech/core/constants/app_assets.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// HearTech brand logo mark — transparent PNG (teal ear + wave lines).
class HearTechLogo extends StatelessWidget {
  final double size;
  final bool showCircleBackground;
  final bool showShadow;

  const HearTechLogo({
    super.key,
    this.size = 64,
    this.showCircleBackground = false,
    this.showShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      AppAssets.logoMark,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.hearing,
          size: size * 0.65,
          color: HearTechColors.deepTeal,
        );
      },
    );

    Widget result = logo;

    if (showCircleBackground) {
      result = Container(
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          shape: BoxShape.circle,
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: HearTechColors.deepTeal.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: logo,
      );
    } else if (showShadow) {
      result = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: HearTechColors.deepTeal.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: logo,
      );
    }

    return result;
  }
}
