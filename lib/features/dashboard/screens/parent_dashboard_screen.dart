import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../handover/widgets/link_child_card.dart';
import '../../invites/widgets/invite_teacher_dialog.dart';
import '../../../shared/widgets/child_card.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
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
        title: const Text('Parent Dashboard'),
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
              Text("Welcome back,", style: AppTheme.subtitle),
              Text("Parent", style: AppTheme.heading1),
              const SizedBox(height: 32),

              // Handover Code Link Card
              LinkChildCard(
                onSubmitCode: (code) async {
                  // TODO: Implement FastAPI call via Dio here
                  await Future.delayed(const Duration(seconds: 2));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Successfully linked code: $code'),
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Children List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Your Children", style: AppTheme.heading2),
                  TextButton(
                    onPressed: () {},
                    child: Text("View All", style: TextStyle(color: AppTheme.primaryTeal)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Mock Child Card
              ChildCard(
                childId: "123",
                name: "Emma",
                ageMonths: 48,
                riskLevel: "Low",
                onTap: () => Navigator.pushNamed(context, AppRouter.childProfile, arguments: {'childId': '123', 'viewerRole': 'parent'}),
              ),
              const SizedBox(height: 12),
              ChildCard(
                childId: "456",
                name: "Noah",
                ageMonths: 36,
                riskLevel: "High",
                onTap: () => Navigator.pushNamed(context, AppRouter.childProfile, arguments: {'childId': '456', 'viewerRole': 'parent'}),
              ),
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                style: AppTheme.secondaryButton,
                onPressed: () {
                  // Quick action for New Screening
                  Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'parent'});
                },
                icon: const Icon(Icons.add),
                label: const Text("Perform Home Screening"),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTeal),
                onPressed: () {
                  InviteTeacherDialog.show(
                    context,
                    onInvite: (email) async {
                      // TODO: Implement FastAPI call
                      await Future.delayed(const Duration(seconds: 1));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invite sent to $email'),
                          backgroundColor: AppTheme.safeGreen,
                        ),
                      );
                    },
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text("Invite Teacher"),
              ),
              
              const SizedBox(height: 32),

              // Educational Tips
              Text("Tips & Resources", style: AppTheme.heading2),
              const SizedBox(height: 16),
              _TipCard(
                title: "Importance of Early Screening",
                description: "Detecting hearing loss early can significantly improve speech and language development outcomes.",
                icon: Icons.lightbulb_outline,
              ),
              const SizedBox(height: 12),
              _TipCard(
                title: "The Ling Six Sound Test",
                description: "Learn how to use these six sounds to check your child's hearing daily at home.",
                icon: Icons.record_voice_over_outlined,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _TipCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const _TipCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(description, style: AppTheme.bodyText.copyWith(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
