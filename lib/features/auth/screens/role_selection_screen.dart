import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';

/// Role selection screen — 3 cards for HCW, Parent, Teacher.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Logo
              const Icon(
                Icons.hearing,
                size: 48,
                color: HearTechColors.deepTeal,
              ),
              const SizedBox(height: 12),
              Text(
                'HearTech',
                style: HearTechTextStyles.screenTitle(
                  color: HearTechColors.deepTeal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your role to continue',
                style: HearTechTextStyles.body(
                  color: HearTechColors.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              // Role cards
              Expanded(
                child: Column(
                  children: [
                    _RoleCard(
                      icon: Icons.medical_services_outlined,
                      title: 'Healthcare Worker',
                      subtitle: 'Screen children for hearing risks',
                      color: HearTechColors.deepTeal,
                      onTap: () => context.go(Routes.hcwLogin),
                    ).animate()
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: -0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.family_restroom,
                      title: 'Parent',
                      subtitle: 'Monitor your child\'s hearing health',
                      color: HearTechColors.mediumTeal,
                      onTap: () => context.go(Routes.parentLogin),
                    ).animate(delay: 80.ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: -0.1, end: 0, duration: 300.ms),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.school_outlined,
                      title: 'Teacher',
                      subtitle: 'Observe classroom hearing behaviours',
                      color: HearTechColors.purple,
                      onTap: () => context.go(Routes.teacherLogin),
                    ).animate(delay: 160.ms)
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: -0.1, end: 0, duration: 300.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          borderRadius: HearTechDecorations.cardBorderRadius,
          boxShadow: HearTechDecorations.cardShadow,
          border: Border.all(
            color: color.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: HearTechTextStyles.sectionHeader()),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: HearTechTextStyles.caption(),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
