import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/di/providers.dart';
import '../../../shared/widgets/child_card.dart';
import '../../notifications/widgets/notification_bell.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(childrenStreamProvider((uid: uid, role: 'teacher')));
    final unread = ref.watch(unreadNotificationCountProvider(uid));

    final userName = userAsync.when(
      data: (u) => u?.name ?? 'Teacher',
      loading: () => '...',
      error: (_, __) => 'Teacher',
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
                        Text('Welcome,', style: AppTheme.subtitle),
                        const SizedBox(height: 4),
                        Text(userName, style: AppTheme.heading1),
                      ],
                    ),
                  ),
                  Row(children: [
                    NotificationBell(unreadCount: unread),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _showSignOutSheet(context),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF8E44AD).withValues(alpha: 0.15),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'T',
                          style: AppTheme.heading2.copyWith(color: const Color(0xFF8E44AD)),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
              const SizedBox(height: 24),

              // ── Pending Invites CTA ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8E44AD), Color(0xFFA569BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mail_outline, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pending Invites', style: AppTheme.heading2.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('You may have new invites from parents',
                              style: AppTheme.caption.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF8E44AD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onPressed: () => Navigator.pushNamed(context, AppRouter.pendingInvites),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Classroom Observation CTA ──
              Container(
                decoration: AppTheme.premiumCard,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.primaryPale, shape: BoxShape.circle),
                      child: const Icon(Icons.record_voice_over, color: AppTheme.primaryTeal, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text('Classroom Observation', style: AppTheme.heading2),
                    const SizedBox(height: 8),
                    Text(
                      'Conduct a quick screening for a student based on classroom behavior and response.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppTheme.primaryButton,
                        onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'teacher'}),
                        child: const Text('Start Observation'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── My Students ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Students', style: AppTheme.heading2),
                  TextButton(
                    onPressed: () {},
                    child: Text('View Class', style: TextStyle(color: AppTheme.primaryTeal)),
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
                      child: Column(children: [
                        Icon(Icons.groups, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No children assigned. Accept an invite from a parent to get started.',
                          style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    );
                  }
                  return Column(
                    children: children.map((child) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ChildCard(
                        childId: child.childId,
                        name: child.name,
                        ageMonths: DateTime.now().difference(child.dob).inDays ~/ 30,
                        riskLevel: child.riskLevel.isNotEmpty
                            ? child.riskLevel[0].toUpperCase() + child.riskLevel.substring(1)
                            : 'Low',
                        onTap: () => Navigator.pushNamed(context, AppRouter.childProfile,
                            arguments: {'childId': child.childId, 'viewerRole': 'teacher'}),
                      ),
                    )).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading students'),
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
  void _showSignOutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
