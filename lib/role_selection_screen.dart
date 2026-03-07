import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'HealthcareWorker/hw_login_screen.dart'; // We will build this below!

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Placeholder / Icon
              const Icon(Icons.hearing, size: 80, color: AppTheme.primaryTeal),
              const SizedBox(height: 24),

              // Title
              Text(
                "Welcome to HearTech",
                textAlign: TextAlign.center,
                style: AppTheme.heading1,
              ),
              const SizedBox(height: 8),
              Text(
                "Please select your role to continue.",
                textAlign: TextAlign.center,
                style: AppTheme.subtitle,
              ),
              const SizedBox(height: 48),

              // Role Buttons
              _buildRoleCard(
                context: context,
                title: "Parent / Caregiver",
                icon: Icons.family_restroom,
                onTap: () {
                  // TODO: Navigate to Parent Login
                },
              ),
              const SizedBox(height: 16),

              _buildRoleCard(
                context: context,
                title: "Teacher",
                icon: Icons.school,
                onTap: () {
                  // TODO: Navigate to Teacher Login
                },
              ),
              const SizedBox(height: 16),

              _buildRoleCard(
                context: context,
                title: "Healthcare Worker",
                icon: Icons.medical_services,
                onTap: () {
                  // Navigate to the Healthcare Worker Login
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HWLoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Widget for the big beautiful buttons
  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.primaryCard,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightMint.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryTeal, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                title,
                style: AppTheme.heading2.copyWith(fontSize: 18),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textGrey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
