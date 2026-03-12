import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';

import '../../../core/router/app_router.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.roleBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ).animate().scale(
                      delay: 200.ms,
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'HearTech',
                textAlign: TextAlign.center,
                style: AppTheme.display.copyWith(
                  color: const Color(0xFF006D77),
                ),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.2),

              const SizedBox(height: 4),
              Text(
                'Early Hearing Tracker',
                textAlign: TextAlign.center,
                style: AppTheme.subtitle.copyWith(
                  color: const Color(0xFF006D77),
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 40),

              Text(
                'Select Your Role',
                textAlign: TextAlign.center,
                style: AppTheme.heading2.copyWith(
                  color: const Color(0xFF006D77),
                ),
              ).animate().fade(delay: 450.ms),

              const SizedBox(height: 20),

              // Role cards
              _BouncyRoleCard(
                title: 'Parent / Caregiver',
                icon: Icons.family_restroom,
                iconColor: Colors.purple,
                iconBgColor: Colors.purple.withValues(alpha: 0.1),
                delay: 500,
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.parentLogin),
              ),
              const SizedBox(height: 16),

              _BouncyRoleCard(
                title: 'Teacher',
                icon: Icons.school,
                iconColor: Colors.teal,
                iconBgColor: Colors.teal.withValues(alpha: 0.1),
                delay: 600,
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.teacherLogin),
              ),
              const SizedBox(height: 16),

              _BouncyRoleCard(
                title: 'Healthcare Worker',
                icon: Icons.medical_services,
                iconColor: Colors.blue.shade700,
                iconBgColor: Colors.blue.withValues(alpha: 0.1),
                delay: 700,
                onTap: () =>
                    Navigator.pushNamed(context, AppRouter.hcwLogin),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bouncy Role Card ──────────────────────────────────────────
class _BouncyRoleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final int delay;
  final VoidCallback onTap;

  const _BouncyRoleCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_BouncyRoleCard> createState() => _BouncyRoleCardState();
}

class _BouncyRoleCardState extends State<_BouncyRoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTheme.heading2.copyWith(
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
      )
          .animate()
          .fade(delay: widget.delay.ms, duration: 500.ms)
          .slideX(begin: 0.1),
    );
  }
}
