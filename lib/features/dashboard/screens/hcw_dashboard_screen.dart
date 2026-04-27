import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/summary_card.dart';
import 'package:heartech/shared/widgets/child_card.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/bell_icon_with_badge.dart';
import 'package:heartech/shared/widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';

/// HCW Dashboard — greeting, stats, recent patients, quick actions.
/// Bottom nav: Home | Patients | Profile
class HcwDashboardScreen extends ConsumerStatefulWidget {
  const HcwDashboardScreen({super.key});

  @override
  ConsumerState<HcwDashboardScreen> createState() => _HcwDashboardScreenState();
}

class _HcwDashboardScreenState extends ConsumerState<HcwDashboardScreen> {
  final int _navIndex = 0;

  void _onNavTap(int index) {
    switch (index) {
      case 0: break; // already on home
      case 1: context.go(Routes.hcwPatients); break;
      case 2: context.go(Routes.hcwProfile); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);
    final childrenAsync = ref.watch(hcwChildrenProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator(message: 'Loading dashboard...')),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: LoadingIndicator(message: 'Loading profile...'));
        }

        return Scaffold(
          backgroundColor: HearTechColors.background,
          bottomNavigationBar: HearTechBottomNavBar(
            currentIndex: _navIndex,
            onTap: _onNavTap,
            role: 'hcw',
          ),
          body: SafeArea(
            child: RefreshIndicator(
              color: HearTechColors.deepTeal,
              onRefresh: () async {
                ref.invalidate(hcwChildrenProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.go(Routes.hcwProfile),
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
                              Text(
                                'Good ${_greeting()}, ${user.title ?? ''} ${user.firstName}',
                                style: HearTechTextStyles.sectionHeader(),
                              ),
                              Text(
                                DateFormat('EEEE, d MMMM').format(DateTime.now()),
                                style: HearTechTextStyles.caption(),
                              ),
                            ],
                          ),
                        ),
                        BellIconWithBadge(
                          uid: user.uid,
                          onTap: () => context.go(Routes.hcwNotifications),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                    const SizedBox(height: 24),

                    // ── Verification warning (if unverified) ─────────
                    if (user.isVerified == false)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: HearTechColors.warmOrange.withValues(alpha: 0.1),
                          borderRadius: HearTechDecorations.cardBorderRadius,
                          border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pending_outlined, color: HearTechColors.warmOrange, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your license is pending verification. Some features are restricted until your account is approved.',
                                style: HearTechTextStyles.caption(color: HearTechColors.warmOrange),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),

                    // ── Stats row (4 cards) ──────────────────────────
                    childrenAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (children) {
                        final total = children.length;
                        final highRisk = children.where((c) => c.riskLevel == 'high').length;
                        // Screenings this week placeholder (count children screened in last 7 days)
                        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
                        final screenedThisWeek = children.where((c) =>
                            c.lastScreeningDate != null && c.lastScreeningDate!.isAfter(weekAgo)).length;
                        final unclaimed = children.where((c) => !c.isClaimed).length;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 140,
                                child: SummaryCard(icon: Icons.people, value: '$total', label: 'Total Patients'),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: SummaryCard(icon: Icons.warning_amber, value: '$highRisk',
                                    label: 'High Risk', iconColor: HearTechColors.coralRed),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: SummaryCard(icon: Icons.assignment_turned_in, value: '$screenedThisWeek',
                                    label: 'This Week', iconColor: HearTechColors.green),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 140,
                                child: SummaryCard(icon: Icons.schedule, value: '$unclaimed',
                                    label: 'Pending Referrals', iconColor: HearTechColors.warmOrange),
                              ),
                            ],
                          ),
                        ).animate(delay: 100.ms).fadeIn(duration: 300.ms);
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── New Screening button (full width) ────────────
                    HearTechButton(
                      label: 'New Screening',
                      icon: Icons.add,
                      onPressed: () => context.go(Routes.hcwNewScreening),
                    ),
                    const SizedBox(height: 12),
                    HearTechButton(
                      label: 'View My Patients',
                      onPressed: () => context.go(Routes.hcwPatients),
                      isSecondary: true,
                    ),
                    const SizedBox(height: 24),

                    // ── Recent Activity ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Recent Activity', style: HearTechTextStyles.sectionHeader()),
                        TextButton(
                          onPressed: () => context.go(Routes.hcwPatients),
                          child: Text('See All', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    childrenAsync.when(
                      loading: () => const LoadingIndicator(),
                      error: (e, _) => Text('Error: $e'),
                      data: (children) {
                        if (children.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: HearTechDecorations.cardDecoration,
                            child: Column(
                              children: [
                                Icon(Icons.child_care, size: 48, color: HearTechColors.deepTeal.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('No patients yet', style: HearTechTextStyles.subtitle()),
                                const SizedBox(height: 4),
                                Text('Start a screening to add your first patient.',
                                    style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 180,
                                  child: HearTechButton(
                                    label: 'New Screening',
                                    onPressed: () => context.go(Routes.hcwNewScreening),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Show latest 5
                        final sorted = [...children]
                          ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));
                        final recent = sorted.take(5).toList();

                        return Column(
                          children: recent.asMap().entries.map((entry) {
                            final child = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ChildCard(
                                name: child.name,
                                ageString: child.ageString,
                                riskLevel: child.riskLevel,
                                riskScore: child.riskScore,
                                photoUrl: child.profilePhotoUrl,
                                showScore: true,
                                onTap: () => context.go(
                                  Routes.hcwChildProfile.replaceFirst(':childId', child.childId),
                                ),
                              ).animate(delay: (300 + entry.key * 80).ms)
                                  .fadeIn(duration: 250.ms)
                                  .slideX(begin: -0.1, end: 0, duration: 250.ms),
                            );
                          }).toList(),
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
