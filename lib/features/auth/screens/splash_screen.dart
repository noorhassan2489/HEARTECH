import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';

/// Splash screen — HearTech ear logo, tagline, auto-routes after 2s.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    // Auto-route after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), _navigate);
  }

  void _navigate() {
    if (!mounted) return;

    final firebaseUser = ref.read(currentFirebaseUserProvider);
    if (firebaseUser == null) {
      context.go(Routes.roleSelect);
      return;
    }

    // User is logged in — check their role and route accordingly
    final userProfile = ref.read(userProfileProvider);
    if (userProfile == null) {
      // Profile not loaded yet — go to role select (they'll be redirected)
      context.go(Routes.roleSelect);
      return;
    }

    switch (userProfile.role) {
      case 'hcw':
        context.go(Routes.hcwDashboard);
      case 'parent':
        context.go(Routes.parentDashboard);
      case 'teacher':
        context.go(Routes.teacherDashboard);
      default:
        context.go(Routes.roleSelect);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.paleTeal,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ear logo icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: HearTechColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: HearTechColors.deepTeal.withValues(alpha: 0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.hearing,
                        size: 64,
                        color: HearTechColors.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // App name
                    Text(
                      'HearTech',
                      style: HearTechTextStyles.bigNumber(
                        color: HearTechColors.deepTeal,
                      ).copyWith(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    // Tagline
                    Text(
                      'Early Hearing, Better Futures',
                      style: HearTechTextStyles.body(
                        color: HearTechColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
