import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../../shared/widgets/summary_card.dart';

class HCWDashboardScreen extends StatefulWidget {
  const HCWDashboardScreen({super.key});

  @override
  State<HCWDashboardScreen> createState() => _HCWDashboardScreenState();
}

class _HCWDashboardScreenState extends State<HCWDashboardScreen> {
  final _authService = FirebaseAuthService();

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('HCW Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Welcome back,",
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text("Dr. Smith", style: AppTheme.heading2),
                    ],
                  ),
                  Row(
                    children: [
                      const NotificationBell(unreadCount: 5), // Mock
                      const SizedBox(width: 12),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.primaryPale,
                        child: Text("D", style: AppTheme.heading2.copyWith(color: AppTheme.primaryTeal)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text("Dashboard", style: AppTheme.heading1),
              const SizedBox(height: 32),

              // Summary Stats
              Row(
                children: [
                  Expanded(
                    child: SummaryCard(
                      title: "Screenings\nThis Week",
                      value: "14",
                      icon: Icons.analytics_outlined,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SummaryCard(
                      title: "High Risk\nIdentified",
                      value: "2",
                      icon: Icons.warning_amber_rounded,
                      color: AppTheme.accentCoral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Main CTA
              ElevatedButton.icon(
                style: AppTheme.primaryButton.copyWith(
                  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20)),
                ),
                onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'hcw'}),
                icon: const Icon(Icons.hearing, size: 28),
                label: const Text("Conduct New Clinical Screening", style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 32),

              // Recent Screenings Activity Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Recent Screenings", style: AppTheme.heading2),
                  TextButton(
                    onPressed: () {},
                    child: Text("View All", style: TextStyle(color: AppTheme.primaryTeal)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Activity Feed Placeholder
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      "No recent clinical screenings found.",
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
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

