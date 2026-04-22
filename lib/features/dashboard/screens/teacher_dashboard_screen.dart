import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/child_card.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/bell_icon_with_badge.dart';
import 'package:heartech/shared/widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';

/// Teacher Dashboard — greeting, live pending invites banner (StreamBuilder),
/// linked students via My Class, observation CTA.
/// Bottom nav: Home | My Class | Notifications | Profile
class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  final int _navIndex = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0: break;
      case 1: context.go(Routes.teacherMyClass); break;
      case 2: context.go(Routes.teacherNotifications); break;
      case 3: context.go(Routes.teacherProfile); break;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(teacherChildrenProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator(message: 'Loading dashboard...')),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: LoadingIndicator());

        return Scaffold(
          backgroundColor: HearTechColors.background,
          bottomNavigationBar: HearTechBottomNavBar(
            currentIndex: _navIndex,
            onTap: _onNavTap,
            role: 'teacher',
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────
                  Row(
                    children: [
                      AvatarCircle(name: user.name, photoUrl: user.profilePhotoUrl, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_greeting()}, ${user.firstName}!',
                                style: HearTechTextStyles.sectionHeader()),
                            Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: HearTechTextStyles.caption()),
                          ],
                        ),
                      ),
                      BellIconWithBadge(uid: user.uid, onTap: () => context.go(Routes.teacherNotifications)),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),

                  // ── Pending Invites Banner (LIVE StreamBuilder) ─────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestorePaths.invites)
                        .where('teacherUid', isEqualTo: user.uid)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                      if (count == 0) return const SizedBox.shrink();

                      return GestureDetector(
                        onTap: () => context.go(Routes.teacherInvites),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: HearTechColors.purple,
                            borderRadius: HearTechDecorations.cardBorderRadius,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school, color: HearTechColors.white, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('You have $count pending invite${count == 1 ? '' : 's'}',
                                        style: HearTechTextStyles.subtitle(color: HearTechColors.white)),
                                    Text('Tap to view and respond',
                                        style: HearTechTextStyles.caption(
                                            color: HearTechColors.white.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: HearTechColors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('View Invites',
                                    style: HearTechTextStyles.caption(color: HearTechColors.white)
                                        .copyWith(fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 300.ms);
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── My Students / My Class ─────────────────
                  childrenAsync.when(
                    loading: () => const LoadingIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (children) {
                      if (children.isEmpty) {
                        return _buildEmptyState();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('My Class', style: HearTechTextStyles.sectionHeader()),
                              Text('${children.length} children',
                                  style: HearTechTextStyles.caption()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...children.asMap().entries.map((entry) {
                            final child = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ChildCard(
                                name: child.name,
                                ageString: child.ageString,
                                riskLevel: child.riskLevel,
                                // Teacher sees label only — no score number
                                photoUrl: child.profilePhotoUrl,
                                onTap: () => context.go(
                                  Routes.teacherChildProfile
                                      .replaceFirst(':childId', child.childId),
                                ),
                              ).animate(delay: (300 + entry.key * 80).ms)
                                  .fadeIn(duration: 250.ms)
                                  .slideX(begin: -0.1, end: 0, duration: 250.ms),
                            );
                          }),
                          const SizedBox(height: 16),
                          HearTechButton(
                            label: 'Submit Observation',
                            onPressed: () => context.go(Routes.teacherObservation),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school_outlined, size: 56, color: HearTechColors.purple),
          ),
          const SizedBox(height: 20),
          Text('No Children Assigned Yet', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text(
            'Accept an invite from a parent to get started.',
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          HearTechButton(
            label: 'Check Invites',
            onPressed: () => context.go(Routes.teacherInvites),
            isSecondary: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
