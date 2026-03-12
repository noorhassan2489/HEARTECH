import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../invites/widgets/pending_invites_list.dart';
import '../../../services/firebase_auth_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final _authService = FirebaseAuthService();

  Future<void> _handleSignOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
    }
  }

  // Mock data for UI building
  final List<PendingInvite> _mockInvites = [
    PendingInvite(
      id: "inv-001",
      childName: "Emma Thompson",
      parentName: "Sarah Thompson",
      riskLevel: "High",
      dateSent: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    PendingInvite(
      id: "inv-002",
      childName: "Noah Wilson",
      parentName: "David Wilson",
      riskLevel: "Medium",
      dateSent: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
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
              Text("Teacher", style: AppTheme.heading1),
              const SizedBox(height: 32),

              // Main CTA
              Container(
                decoration: AppTheme.premiumCard,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPale,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.record_voice_over, color: AppTheme.primaryTeal, size: 40),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Classroom Observation",
                      style: AppTheme.heading2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Conduct a quick screening for a student based on classroom behavior and response.",
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppTheme.primaryButton,
                        onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'teacher'}),
                        child: const Text("Start Observation"),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Pending Invites Section
              PendingInvitesList(
                invites: _mockInvites,
                onRespond: (inviteId, accept) async {
                  // TODO: FastAPI Integration
                  await Future.delayed(const Duration(seconds: 1));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(accept ? 'Invite accepted' : 'Invite declined'),
                      backgroundColor: accept ? AppTheme.safeGreen : AppTheme.textSecondary,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Students List Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("My Students", style: AppTheme.heading2),
                  TextButton(
                    onPressed: () {},
                    child: Text("View Class", style: TextStyle(color: AppTheme.primaryTeal)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // No students placeholder
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  children: [
                    Icon(Icons.groups, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      "No students added yet.",
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: AppTheme.secondaryButton,
                      onPressed: () {
                        Navigator.pushNamed(context, AppRouter.childCreate);
                      },
                      child: const Text("Add Student"),
                    )
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
