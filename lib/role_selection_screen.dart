import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../theme/page_transitions.dart';
import 'HealthcareWorker/hw_login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.premiumBackground,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Headers with staggered entrance
                const Icon(
                  Icons.stream,
                  size: 70,
                  color: AppTheme.primaryTeal,
                ).animate().scale(
                  delay: 200.ms,
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
                const SizedBox(height: 24),

                Text(
                  "HearTech",
                  textAlign: TextAlign.center,
                  style: AppTheme.heading1.copyWith(fontSize: 36),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2),

                Text(
                  "Select your portal to begin",
                  textAlign: TextAlign.center,
                  style: AppTheme.subtitle,
                ).animate().fade(delay: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 50),

                // Bouncy Interactive Cards
                BouncyRoleCard(
                  title: "Parent / Caregiver",
                  icon: Icons.face_retouching_natural,
                  delay: 500,
                  onTap: () {},
                ),
                const SizedBox(height: 20),

                BouncyRoleCard(
                  title: "Educator / Teacher",
                  icon: Icons.auto_stories,
                  delay: 600,
                  onTap: () {},
                ),
                const SizedBox(height: 20),

                BouncyRoleCard(
                  title: "Healthcare Worker",
                  icon: Icons.medical_information,
                  delay: 700,
                  onTap: () {
                    // Use our custom buttery transition!
                    Navigator.push(
                      context,
                      PremiumTransition(page: const HWLoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// THE BOUNCY CARD WIDGET (For that premium tactile feel)
// --------------------------------------------------------
class BouncyRoleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final int delay;
  final VoidCallback onTap;

  const BouncyRoleCard({
    super.key,
    required this.title,
    required this.icon,
    required this.delay,
    required this.onTap,
  });

  @override
  State<BouncyRoleCard> createState() => _BouncyRoleCardState();
}

class _BouncyRoleCardState extends State<BouncyRoleCard> {
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
      child:
          AnimatedScale(
                scale: _isPressed ? 0.95 : 1.0, // The squish effect!
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.premiumCard,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryTeal, AppTheme.lightMint],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: AppTheme.heading2.copyWith(fontSize: 18),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppTheme.primaryTeal,
                      ),
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
