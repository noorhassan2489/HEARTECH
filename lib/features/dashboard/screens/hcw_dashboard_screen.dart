import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/di/providers.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../../shared/widgets/child_card.dart';
import '../../notifications/widgets/notification_bell.dart';

class HCWDashboardScreen extends ConsumerWidget {
  const HCWDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(childrenStreamProvider((uid: uid, role: 'hcw')));
    final unread = ref.watch(unreadNotificationCountProvider(uid));

    final userName = userAsync.when(
      data: (u) => u?.name ?? 'Doctor',
      loading: () => '...',
      error: (_, __) => 'Doctor',
    );

    final isVerified = userAsync.when(
      data: (u) => u?.isVerified ?? true,
      loading: () => true,
      error: (_, __) => true,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning,', style: AppTheme.subtitle),
                        const SizedBox(height: 4),
                        Text('Dr. $userName', style: AppTheme.heading1),
                      ],
                    ),
                  ),
                  Row(children: [
                    NotificationBell(unreadCount: unread),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showLogoutSheet(context),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primaryPale,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'D',
                          style: AppTheme.heading2.copyWith(color: AppTheme.primaryTeal),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),

              const SizedBox(height: 16),

              // ── Verification Warning ──
              if (!isVerified)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentYellow.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppTheme.accentYellow, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your license is pending verification. Some features are restricted.',
                          style: AppTheme.bodyText.copyWith(color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Stats Row ──
              childrenAsync.when(
                data: (children) {
                  final highRisk = children.where((c) => c.riskLevel == 'high').length;
                  return Row(
                    children: [
                      Expanded(child: SummaryCard(
                        title: 'Total\nPatients', value: '${children.length}',
                        icon: Icons.people_outline, color: AppTheme.primaryTeal,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: SummaryCard(
                        title: 'High Risk\nPatients', value: '$highRisk',
                        icon: Icons.warning_amber_rounded, color: AppTheme.accentCoral,
                      )),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Row(
                  children: [
                    Expanded(child: SummaryCard(title: 'Total\nPatients', value: '0', icon: Icons.people_outline, color: AppTheme.primaryTeal)),
                    const SizedBox(width: 16),
                    Expanded(child: SummaryCard(title: 'High Risk\nPatients', value: '0', icon: Icons.warning_amber_rounded, color: AppTheme.accentCoral)),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Quick Actions ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButton.copyWith(
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20)),
                      ),
                      onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'hcw'}),
                      icon: const Icon(Icons.hearing, size: 24),
                      label: const Text('New Screening'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppTheme.secondaryButton.copyWith(
                        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 20)),
                      ),
                      onPressed: () {}, // TODO: My Patients screen
                      icon: const Icon(Icons.folder_shared_outlined, size: 24),
                      label: const Text('My Patients'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Recent Activity ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent Activity', style: AppTheme.heading2),
                  TextButton(onPressed: () {}, child: Text('View All', style: TextStyle(color: AppTheme.primaryTeal))),
                ],
              ),
              const SizedBox(height: 12),

              childrenAsync.when(
                data: (children) {
                  if (children.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: AppTheme.cardDecoration,
                      child: Column(children: [
                        Icon(Icons.history, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text('No patients yet. Conduct a screening to get started.',
                            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
                      ]),
                    );
                  }
                  return Column(
                    children: children.take(5).map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChildCard(
                        childId: child.childId,
                        name: child.name,
                        ageMonths: DateTime.now().difference(child.dob).inDays ~/ 30,
                        riskLevel: child.riskLevel.isNotEmpty
                            ? child.riskLevel[0].toUpperCase() + child.riskLevel.substring(1)
                            : 'Low',
                        onTap: () => Navigator.pushNamed(context, AppRouter.childProfile,
                            arguments: {'childId': child.childId, 'viewerRole': 'hcw'}),
                      ),
                    )).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading patients'),
              ),

              // ── Disclaimer ──
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPale.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'HearTech is a screening tool, not a medical diagnosis. Always consult a qualified healthcare professional.',
                  style: AppTheme.caption.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Sign Out?', style: AppTheme.heading2),
          const SizedBox(height: 16),
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
                  (route) => false, // Remove ALL routes from the stack
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
