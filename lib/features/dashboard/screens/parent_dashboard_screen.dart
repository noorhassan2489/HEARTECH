import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/di/providers.dart';
import '../../../shared/widgets/child_card.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../handover/widgets/link_child_card.dart';

class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(
      childrenStreamProvider((uid: uid, role: 'parent')),
    );
    final unread = ref.watch(unreadNotificationCountProvider(uid));

    final userName = userAsync.when(
      data: (u) => u?.name ?? 'Parent',
      loading: () => '...',
      error: (_, __) => 'Parent',
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
                        Text('Hello,', style: AppTheme.subtitle),
                        const SizedBox(height: 4),
                        Text(userName, style: AppTheme.heading1),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      NotificationBell(unreadCount: unread),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _showSignOutSheet(context),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.primaryPale,
                          child: Text(
                            userName.isNotEmpty
                                ? userName[0].toUpperCase()
                                : 'P',
                            style: AppTheme.heading2.copyWith(
                              color: AppTheme.primaryTeal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Handover Code Entry ──
              LinkChildCard(
                onSubmitCode: (code) async {
                  // TODO: Call FastAPI /api/claim-profile
                  await Future.delayed(const Duration(seconds: 2));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Linking code: $code...'),
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Children List ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Children', style: AppTheme.heading2),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'View All',
                      style: TextStyle(color: AppTheme.primaryTeal),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              childrenAsync.when(
                data: (children) {
                  if (children.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        children: [
                          Icon(
                            Icons.child_care,
                            size: 48,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No profiles yet. Enter the code from your healthcare worker to link your child\'s profile.',
                            style: AppTheme.bodyText.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: children
                        .map(
                          (child) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChildCard(
                              childId: child.childId,
                              name: child.name,
                              ageMonths:
                                  DateTime.now().difference(child.dob).inDays ~/
                                  30,
                              riskLevel: child.riskLevel.isNotEmpty
                                  ? child.riskLevel[0].toUpperCase() +
                                        child.riskLevel.substring(1)
                                  : 'Low',
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRouter.childProfile,
                                arguments: {
                                  'childId': child.childId,
                                  'viewerRole': 'parent',
                                },
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading children'),
              ),

              const SizedBox(height: 24),

              // ── Quick Actions ──
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: AppTheme.primaryButton.copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRouter.newScreening,
                        arguments: {'role': 'parent'},
                      ),
                      icon: const Icon(Icons.hearing, size: 22),
                      label: const Text('Home Screening'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: AppTheme.secondaryButton.copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRouter.speechModules),
                      icon: const Icon(
                        Icons.record_voice_over_outlined,
                        size: 22,
                      ),
                      label: const Text('Speech Games'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Tips ──
              Text('Tips & Resources', style: AppTheme.heading2),
              const SizedBox(height: 12),
              _TipCard(
                title: 'Importance of Early Screening',
                description:
                    'Detecting hearing loss early can significantly improve speech and language development outcomes.',
                icon: Icons.lightbulb_outline,
              ),
              const SizedBox(height: 12),
              _TipCard(
                title: 'The Ling Six Sound Test',
                description:
                    'Learn how to use these six sounds to check your child\'s hearing daily at home.',
                icon: Icons.record_voice_over_outlined,
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
                Text(
                  title,
                  style: AppTheme.bodyText.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.bodyText.copyWith(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSignOutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign Out?', style: AppTheme.heading2),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
          ],
        ),
      ),
    );
  }
}
