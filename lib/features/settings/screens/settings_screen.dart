import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';

/// A general settings screen reachable from all dashboards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Notification preferences
          _buildTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notification Preferences',
            subtitle: 'Manage which alerts you receive',
            onTap: () => Navigator.pushNamed(context, AppRouter.notificationPrefs),
          ),
          const SizedBox(height: 12),

          // Privacy
          _buildTile(
            context,
            icon: Icons.lock_outline,
            title: 'Privacy & Security',
            subtitle: 'Manage your data and account security',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon')),
              );
            },
          ),
          const SizedBox(height: 12),

          // About
          _buildTile(
            context,
            icon: Icons.info_outline,
            title: 'About HearTech',
            subtitle: 'Version 1.0.0 • Built with ❤',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'HearTech',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 HearTech. All rights reserved.',
              );
            },
          ),
          const SizedBox(height: 32),

          // Sign Out
          ElevatedButton.icon(
            onPressed: () => _showSignOutDialog(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primaryTeal),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Sign Out?', style: AppTheme.heading2),
          const SizedBox(height: 8),
          Text('You will need to sign in again to access your data.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (ctx.mounted) {
                Navigator.of(ctx).pushNamedAndRemoveUntil(
                  AppRouter.roleSelect,
                  (route) => false,
                );
              }
            },
            child: const Text('Sign Out'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ]),
      ),
    );
  }
}
