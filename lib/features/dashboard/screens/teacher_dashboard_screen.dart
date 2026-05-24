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
import 'package:heartech/shared/models/child_model.dart';
import 'package:intl/intl.dart';

/// Teacher Dashboard — classroom-centric design with observation tips,
/// visual classroom grid, streak tracker, and quick actions.
/// Bottom nav: Home | My Class | Profile
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
      case 2: context.go(Routes.teacherProfile); break;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // ── Daily observation tips (rotate by day of year) ───────────────────────
  static const _tips = [
    _Tip(
      '👂 Listen for "What?"',
      'If a child frequently asks "What?" or "Huh?", it may signal difficulty hearing — especially in noisy environments.',
      Icons.hearing,
    ),
    _Tip(
      '📍 Seating Matters',
      'Children with hearing difficulties benefit from sitting near the front, away from windows and doors that create background noise.',
      Icons.event_seat,
    ),
    _Tip(
      '🗣️ Watch for Speech Changes',
      'A child speaking too loudly or too softly, or mispronouncing common words, may need a hearing check.',
      Icons.record_voice_over,
    ),
    _Tip(
      '👀 Eye Contact Cues',
      'If a child watches your lips closely or turns one ear toward you, they may be compensating for hearing loss.',
      Icons.visibility,
    ),
    _Tip(
      '🎵 Music & Rhymes',
      'Difficulty keeping up with songs, rhymes, or rhythm activities can be an early indicator of auditory processing issues.',
      Icons.music_note,
    ),
    _Tip(
      '📝 Document Patterns',
      'Note when and where hearing issues occur. Is it louder environments? Group settings? This helps HCWs during assessment.',
      Icons.edit_note,
    ),
    _Tip(
      '🤫 The Quiet Check',
      'Try giving instructions in a normal voice from 3 metres away. If a child consistently misses them, flag it for observation.',
      Icons.spatial_audio_off,
    ),
  ];

  _Tip get _todaysTip => _tips[DateTime.now().difference(DateTime(2024)).inDays % _tips.length];

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(teacherChildrenProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator(message: 'Loading dashboard...')),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          final firebaseUser = ref.read(currentFirebaseUserProvider);
          if (firebaseUser != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go(Routes.roleSelect);
            });
          }
          return const Scaffold(body: LoadingIndicator());
        }

        return Scaffold(
          backgroundColor: HearTechColors.background,
          bottomNavigationBar: HearTechBottomNavBar(
            currentIndex: _navIndex,
            onTap: _onNavTap,
            role: 'teacher',
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: HearTechColors.purple,
              onRefresh: () async => ref.invalidate(teacherChildrenProvider),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(Routes.teacherProfile),
                          child: AvatarCircle(
                            name: user.name,
                            photoUrl: user.profilePhotoUrl,
                            radius: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_greeting()}, ${user.firstName}!',
                                  style: HearTechTextStyles.sectionHeader()),
                              Text(
                                user.schoolName != null && user.schoolName!.isNotEmpty
                                    ? '${user.schoolName} · ${DateFormat('EEEE').format(DateTime.now())}'
                                    : DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: HearTechTextStyles.caption(),
                              ),
                            ],
                          ),
                        ),
                        BellIconWithBadge(
                          uid: user.uid,
                          onTap: () => context.go(Routes.teacherNotifications),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 24),

                    // ── Pending Invites Banner (only if count > 0) ─────
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirestorePaths.invites)
                          .where('teacherUid', isEqualTo: user.uid)
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                        if (count == 0) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: GestureDetector(
                            onTap: () => context.go(Routes.teacherInvites),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C4DFF), Color(0xFF9C7CFF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: HearTechDecorations.cardBorderRadius,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: HearTechColors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.mail, color: HearTechColors.white, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('$count New Invite${count == 1 ? '' : 's'}',
                                            style: HearTechTextStyles.subtitle(color: HearTechColors.white)),
                                        Text('A parent wants to connect you with their child',
                                            style: HearTechTextStyles.caption(
                                                color: HearTechColors.white.withValues(alpha: 0.85))),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios,
                                      color: HearTechColors.white, size: 16),
                                ],
                              ),
                            ),
                          ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: -0.05, end: 0),
                        );
                      },
                    ),

                    // ── Classroom At a Glance ───────────────────
                    childrenAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, s) => const SizedBox.shrink(),
                      data: (children) {
                        if (children.isEmpty) return const SizedBox.shrink();
                        return _buildClassroomGlance(children);
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Observation Tip of the Day ───────────────
                    _buildTipCard().animate(delay: 300.ms).fadeIn(duration: 300.ms),
                    const SizedBox(height: 20),

                    // ── Quick Actions ───────────────────────────
                    Text('Quick Actions', style: HearTechTextStyles.sectionHeader()),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.edit_note,
                            label: 'Submit\nObservation',
                            color: HearTechColors.deepTeal,
                            onTap: () => context.go(Routes.teacherObservation),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.people_outline,
                            label: 'View\nMy Class',
                            color: HearTechColors.purple,
                            onTap: () => context.go(Routes.teacherMyClass),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.mail_outline,
                            label: 'Check\nInvites',
                            color: HearTechColors.warmOrange,
                            onTap: () => context.go(Routes.teacherInvites),
                          ),
                        ),
                      ],
                    ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
                    const SizedBox(height: 24),

                    // ── Your Students ───────────────────────────
                    childrenAsync.when(
                      loading: () => const LoadingIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (children) {
                        if (children.isEmpty) return _buildEmptyState();

                        final sorted = [...children]
                          ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
                        final recent = sorted.take(5).toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Your Students', style: HearTechTextStyles.sectionHeader()),
                                TextButton(
                                  onPressed: () => context.go(Routes.teacherMyClass),
                                  child: Text('See All (${children.length})',
                                      style: HearTechTextStyles.caption(
                                          color: HearTechColors.deepTeal)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...recent.asMap().entries.map((entry) {
                              final child = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ChildCard(
                                  name: child.name,
                                  ageString: child.ageString,
                                  riskLevel: child.riskLevel,
                                  photoUrl: child.profilePhotoUrl,
                                  onTap: () => context.go(
                                    Routes.teacherChildProfile
                                        .replaceFirst(':childId', child.childId),
                                  ),
                                ).animate(delay: (500 + entry.key * 80).ms)
                                    .fadeIn(duration: 250.ms)
                                    .slideX(begin: -0.1, end: 0, duration: 250.ms),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Classroom At a Glance ─────────────────────────────────────────────────
  Widget _buildClassroomGlance(List<ChildModel> children) {
    final high = children.where((c) => c.riskLevel == 'high').length;
    final med = children.where((c) => c.riskLevel == 'medium').length;
    final low = children.length - high - med;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: HearTechDecorations.subtleShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HearTechColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school, color: HearTechColors.purple, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Classroom At a Glance', style: HearTechTextStyles.sectionHeader()),
            ],
          ),
          const SizedBox(height: 16),
          // Student avatar mosaic (first 8 shown)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...children.take(8).map((child) => _StudentDot(child: child)),
              if (children.length > 8)
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: HearTechColors.paleTeal,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('+${children.length - 8}',
                      style: const TextStyle(
                        fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                        fontSize: 12, color: HearTechColors.deepTeal,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Risk breakdown bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (low > 0) Flexible(flex: low, child: Container(color: HearTechColors.green)),
                  if (med > 0) Flexible(flex: med, child: Container(color: HearTechColors.warmOrange)),
                  if (high > 0) Flexible(flex: high, child: Container(color: HearTechColors.coralRed)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem(HearTechColors.green, '$low Low'),
              _legendItem(HearTechColors.warmOrange, '$med Medium'),
              _legendItem(HearTechColors.coralRed, '$high High'),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 300.ms);
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(
          fontFamily: 'Nunito', fontSize: 12, color: HearTechColors.textSecondary,
        )),
      ],
    );
  }

  // ── Tip of the Day Card ───────────────────────────────────────────────────
  Widget _buildTipCard() {
    final tip = _todaysTip;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HearTechColors.deepTeal.withValues(alpha: 0.08),
            HearTechColors.mediumTeal.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: HearTechColors.deepTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(tip.icon, color: HearTechColors.deepTeal, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Observation Tip', style: TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w600,
                fontSize: 11, color: HearTechColors.deepTeal,
                letterSpacing: 0.8,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HearTechColors.deepTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Daily', style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w600,
                  color: HearTechColors.deepTeal.withValues(alpha: 0.6),
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(tip.title, style: const TextStyle(
            fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 15, color: HearTechColors.textPrimary,
          )),
          const SizedBox(height: 6),
          Text(tip.description, style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 13, color: HearTechColors.textSecondary,
            height: 1.4,
          )),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
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
            'Accept an invite from a parent to get started.\nYour classroom will come to life here.',
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

// ═══════════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _Tip {
  final String title;
  final String description;
  final IconData icon;
  const _Tip(this.title, this.description, this.icon);
}

/// Single student dot in the classroom mosaic — color-coded ring by risk.
class _StudentDot extends StatelessWidget {
  final ChildModel child;
  const _StudentDot({required this.child});

  Color get _ringColor {
    switch (child.riskLevel) {
      case 'high': return HearTechColors.coralRed;
      case 'medium': return HearTechColors.warmOrange;
      default: return HearTechColors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${child.name} — ${child.riskLevel} risk',
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _ringColor, width: 2.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 17,
            backgroundColor: _ringColor.withValues(alpha: 0.15),
            backgroundImage: child.profilePhotoUrl != null && child.profilePhotoUrl!.isNotEmpty
                ? NetworkImage(child.profilePhotoUrl!)
                : null,
            child: child.profilePhotoUrl == null || child.profilePhotoUrl!.isEmpty
                ? Text(
                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                      fontSize: 14, color: _ringColor,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

/// Square quick-action card with icon and two-line label.
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: HearTechDecorations.subtleShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito', fontWeight: FontWeight.w600,
                fontSize: 12, color: HearTechColors.textPrimary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
