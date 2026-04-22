import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/bell_icon_with_badge.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';

/// Parent Dashboard — greeting, claim CTA or child cards, quick actions, tips.
/// Bottom nav: Home | My Children | Speech Games | Notifications | Profile
class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  final int _navIndex = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0: break;
      case 1: context.go(Routes.parentChildren); break;
      case 2: context.go(Routes.parentSpeechGames); break;
      case 3: context.go(Routes.parentNotifications); break;
      case 4: context.go(Routes.parentProfile); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(parentChildrenProvider);

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
            role: 'parent',
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── App Bar Header ──────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Text('Hello, ${user.firstName}!',
                            style: HearTechTextStyles.sectionHeader()),
                      ),
                      BellIconWithBadge(uid: user.uid, onTap: () => context.go(Routes.parentNotifications)),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go(Routes.parentProfile),
                        child: AvatarCircle(name: user.name, photoUrl: user.profilePhotoUrl, radius: 22),
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),

                  // ── Content: empty state or children ────────
                  childrenAsync.when(
                    loading: () => const LoadingIndicator(),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (children) {
                      if (children.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildWithChildren(children, user.uid);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Empty state: no children linked.
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        children: [
          // Parent and child illustration
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.paleTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.family_restroom, size: 64, color: HearTechColors.deepTeal),
          ),
          const SizedBox(height: 24),
          Text('No Profiles Linked Yet', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text(
            "Enter the code from your healthcare worker to link your child's profile.",
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          HearTechButton(
            label: 'Enter Code',
            icon: Icons.qr_code,
            onPressed: () => context.go(Routes.parentClaimProfile),
          ),
          const SizedBox(height: 12),
          Text(
            "Your child's profile will appear here after your HCW creates it.",
            style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  /// State when children are linked.
  Widget _buildWithChildren(List children, String parentUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Claim Profile CTA (always visible)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: HearTechDecorations.cardBorderRadius,
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code, color: HearTechColors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Have another code?',
                    style: HearTechTextStyles.subtitle(color: HearTechColors.white)),
              ),
              SizedBox(
                width: 120,
                height: 40,
                child: HearTechButton(
                  label: 'Enter Code',
                  onPressed: () => context.go(Routes.parentClaimProfile),
                  backgroundColor: HearTechColors.white,
                  textColor: HearTechColors.deepTeal,
                ),
              ),
            ],
          ),
        ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 24),

        // ── Your Children section ──
        Text('Your Children', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, i) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final child = children[index];
              final lastScreening = child.lastScreeningDate;
              return GestureDetector(
                onTap: () => context.go(
                  Routes.parentChildProfile.replaceFirst(':childId', child.childId),
                ),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HearTechColors.white,
                    borderRadius: HearTechDecorations.cardBorderRadius,
                    boxShadow: HearTechDecorations.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarCircle(name: child.name, photoUrl: child.profilePhotoUrl, radius: 26),
                      const SizedBox(height: 8),
                      Text(child.name, style: HearTechTextStyles.subtitle(),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(child.ageString, style: HearTechTextStyles.caption()),
                      const Spacer(),
                      RiskBadge(riskLevel: child.riskLevel),
                      const SizedBox(height: 4),
                      Text(
                        lastScreening != null
                            ? 'Last: ${DateFormat('d MMM').format(lastScreening)}'
                            : 'No screenings',
                        style: HearTechTextStyles.caption(color: HearTechColors.textSecondary)
                            .copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ).animate(delay: (200 + index * 80).ms).fadeIn(duration: 300.ms)
                  .slideX(begin: 0.1, end: 0);
            },
          ),
        ),
        const SizedBox(height: 24),

        // ── Quick Actions ──
        Text('Quick Actions', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.assignment,
                label: 'Run Home\nScreening',
                color: HearTechColors.deepTeal,
                onTap: () => context.go(Routes.parentScreening),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.mic,
                label: 'Speech\nGames',
                color: HearTechColors.mediumTeal,
                onTap: () => context.go(Routes.parentSpeechGames),
              ),
            ),
          ],
        ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 24),

        // ── Hearing Development Tips ──
        Builder(
          builder: (context) {
            int minBracket = 5;
            for (final c in children) {
              if (c.ageBracket < minBracket) minBracket = c.ageBracket;
            }

            final tips = _getTips(minBracket);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hearing Development Tips', style: HearTechTextStyles.sectionHeader()),
                const SizedBox(height: 12),
                SizedBox(
                  height: 135,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tips.length,
                    separatorBuilder: (_, i) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => tips[i],
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _getTips(int bracket) {
    if (bracket == 1) {
      return const [
        _TipCard(title: 'Startling to sounds', body: 'Infants should startle or widen their eyes at sudden, loud noises.'),
        _TipCard(title: 'Soothing voice', body: 'Does your baby calm down or smile when they hear your familiar voice?'),
        _TipCard(title: 'Finding the source', body: 'Watch to see if they move their eyes toward the direction of sounds.'),
      ];
    } else if (bracket == 2) {
      return const [
        _TipCard(title: 'Babbling', body: 'Encourage babbling by responding to their sounds as if having a conversation.'),
        _TipCard(title: 'Name recognition', body: 'By 9 months, they should turn their head when you call their name.'),
        _TipCard(title: 'Imitation', body: 'Try making simple sounds like "ba" and see if they try to copy you.'),
      ];
    } else {
      return const [
        _TipCard(title: 'Simple commands', body: 'Practice giving simple 1-step directions like "get your shoes" without pointing.'),
        _TipCard(title: 'Expand vocabulary', body: 'Read aloud to them every single day. Narrate your daily activities.'),
        _TipCard(title: 'Reduce background noise', body: 'Turn off the TV when speaking to help your child focus on speech sounds.'),
      ];
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          borderRadius: HearTechDecorations.cardBorderRadius,
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: HearTechDecorations.subtleShadow,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: HearTechTextStyles.subtitle(color: color))),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String title;
  final String body;
  const _TipCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HearTechColors.paleTeal,
        borderRadius: HearTechDecorations.cardBorderRadius,
        border: const Border(left: BorderSide(color: HearTechColors.deepTeal, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline, size: 18, color: HearTechColors.deepTeal),
            const SizedBox(width: 6),
            Expanded(child: Text(title, style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal))),
          ]),
          const SizedBox(height: 8),
          Expanded(child: Text(body, style: HearTechTextStyles.caption(), maxLines: 4, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
