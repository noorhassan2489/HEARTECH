import 'package:flutter/material.dart';

/// Slide-up + fade-in page transition used throughout HearTech.
class PremiumTransition extends PageRouteBuilder {
  final Widget page;

  PremiumTransition({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );
          var slideAnimation = Tween<Offset>(
            begin: const Offset(0.0, 0.1),
            end: Offset.zero,
          ).animate(curve);
          var fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curve);

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(position: slideAnimation, child: child),
          );
        },
      );
}

/// Slide right-to-left for forward nav.
class SlideForwardTransition extends PageRouteBuilder {
  final Widget page;

  SlideForwardTransition({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          );
        },
      );
}
