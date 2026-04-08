import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';

/// Splash screen — HearTech ear logo on Pale Teal, auto-routes after 2s.
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

    // Auto-route after 2 seconds
    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) context.go(Routes.roleSelect);
      return;
    }

    // User is logged in — fetch role from Firestore
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final userProfile = await firestoreService.getUser(firebaseUser.uid);

      if (!mounted) return;

      if (userProfile == null) {
        context.go(Routes.roleSelect);
        return;
      }

      // Register OneSignal on app launch with existing session
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.registerOneSignal(firebaseUser.uid, userProfile.role);

      if (!mounted) return;

      switch (userProfile.role) {
        case 'hcw':
          context.go(Routes.hcwDashboard);
          break;
        case 'parent':
          context.go(Routes.parentDashboard);
          break;
        case 'teacher':
          context.go(Routes.teacherDashboard);
          break;
        default:
          context.go(Routes.roleSelect);
      }
    } catch (e) {
      if (mounted) context.go(Routes.roleSelect);
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
                    // Ear logo icon in white circle
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
                    // App name — Nunito ExtraBold 32sp Deep Teal
                    Text(
                      'HearTech',
                      style: HearTechTextStyles.display(
                        color: HearTechColors.deepTeal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Tagline — Text Secondary 14sp
                    Text(
                      'Early Hearing, Better Futures',
                      style: HearTechTextStyles.caption(
                        color: HearTechColors.textSecondary,
                      ).copyWith(fontSize: 14),
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
