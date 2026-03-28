import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ============================================================================
// HEARTECH ANIMATION SYSTEM — Consistent animation constants and helpers
// ============================================================================

class HearTechAnimations {
  HearTechAnimations._();

  // Durations
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);
  static const Duration gauge = Duration(milliseconds: 900);
  static const Duration splash = Duration(milliseconds: 600);
  static const Duration staggerDelay = Duration(milliseconds: 80);
  static const Duration splashWait = Duration(seconds: 2);

  // Curves
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve gaugeCurve = Curves.elasticOut;

  // Button press scale
  static const double buttonPressScale = 0.96;

  // Slide offsets
  static const Offset slideUpOffset = Offset(0, 20);
  static const Offset slideLeftOffset = Offset(-30, 0);
  static const Offset slideRightOffset = Offset(30, 0);
}

/// Extension on Widget to add common HearTech animations.
extension HearTechAnimateExtensions on Widget {
  /// Standard screen entry: fade in + slight slide up.
  Widget animateScreenEntry({int index = 0}) {
    return animate(
      delay: HearTechAnimations.staggerDelay * index,
    )
        .fadeIn(duration: HearTechAnimations.normal)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: HearTechAnimations.normal,
          curve: HearTechAnimations.defaultCurve,
        );
  }

  /// Card stagger animation: fade + slide from left.
  Widget animateCardStagger(int index) {
    return animate(
      delay: HearTechAnimations.staggerDelay * index,
    )
        .fadeIn(duration: HearTechAnimations.normal)
        .slideX(
          begin: -0.1,
          end: 0,
          duration: HearTechAnimations.normal,
          curve: HearTechAnimations.defaultCurve,
        );
  }

  /// Bounce in for success elements.
  Widget animateBounceIn({Duration? delay}) {
    return animate(delay: delay)
        .scale(
          begin: const Offset(0, 0),
          end: const Offset(1, 1),
          duration: HearTechAnimations.slow,
          curve: HearTechAnimations.bounceCurve,
        )
        .fadeIn(duration: HearTechAnimations.normal);
  }

  /// Notification badge bounce.
  Widget animateBadgeBounce() {
    return animate(onPlay: (controller) => controller.forward())
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          duration: HearTechAnimations.fast,
        )
        .then()
        .scale(
          begin: const Offset(1.3, 1.3),
          end: const Offset(1, 1),
          duration: HearTechAnimations.fast,
        );
  }

  /// Pulsing animation for loading states.
  Widget animatePulse() {
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.05, 1.05),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        )
        .fadeIn(
          begin: 0.6,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }

  /// Handover code character bounce in.
  Widget animateHandoverChar(int index) {
    return animate(
      delay: HearTechAnimations.staggerDelay * index,
    ).scale(
      begin: const Offset(0, 0),
      end: const Offset(1, 1),
      duration: HearTechAnimations.normal,
      curve: HearTechAnimations.bounceCurve,
    );
  }
}
