import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart'; // ignore: unused_import, keep for type reference
import 'package:heartech/shared/models/user_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_gauge.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';
import 'package:heartech/shared/models/note_model.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:intl/intl.dart';

/// Child Profile Screen — tabbed interface per role.
/// HCW: Overview | Screenings | Referrals | Notes | Speech Logs
/// Parent: Overview | Screenings | Speech Logs
/// Teacher: Overview | Observations | Speech Logs (limited data)
class ChildProfileScreen extends ConsumerStatefulWidget {
  final String childId;
  final String viewerRole; // hcw, parent, teacher

  const ChildProfileScreen({
    super.key,
    required this.childId,
    required this.viewerRole,
  });

  @override
  ConsumerState<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends ConsumerState<ChildProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<String> get _tabs {
    switch (widget.viewerRole) {
      case 'hcw':
        return ['Overview', 'Screenings', 'Referrals', 'Notes', 'Speech'];
      case 'parent':
        return ['Overview', 'Screenings', 'Referrals', 'Speech'];
      case 'teacher':
        return ['Overview', 'Observations', 'Speech'];
      default:
        return ['Overview'];
    }
  }

  String get _backRoute {
    switch (widget.viewerRole) {
      case 'hcw': return Routes.hcwDashboard;
      case 'parent': return Routes.parentDashboard;
      case 'teacher': return Routes.teacherDashboard;
      default: return Routes.splash;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return StreamBuilder(
      stream: firestoreService.streamChild(widget.childId),
      builder: (context, childSnap) {
        if (childSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingIndicator(message: 'Loading child profile...'));
        }
        final child = childSnap.data;
        if (child == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Child Profile')),
            body: const Center(child: Text('Child not found.')),
          );
        }

        return Scaffold(
          backgroundColor: HearTechColors.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Sliver App Bar with child info ───────────────────
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: HearTechColors.deepTeal,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: HearTechColors.white),
                  onPressed: () => context.go(_backRoute),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 32),
                          AvatarCircle(name: child.name, photoUrl: child.profilePhotoUrl, radius: 36),
                          const SizedBox(height: 12),
                          Text(child.name, style: HearTechTextStyles.screenTitle(color: HearTechColors.white)),
                          const SizedBox(height: 4),
                          Text('${child.ageString} • ${child.gender}',
                              style: HearTechTextStyles.caption(color: HearTechColors.white.withValues(alpha: 0.8))),
                          const SizedBox(height: 8),
                          // Teacher sees label only, not score number
                          if (widget.viewerRole == 'teacher')
                            RiskBadge(riskLevel: child.riskLevel)
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                RiskBadge(riskLevel: child.riskLevel),
                                const SizedBox(width: 8),
                                Text('Score: ${child.riskScore}%',
                                    style: HearTechTextStyles.caption(color: HearTechColors.white.withValues(alpha: 0.7))),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tab bar ──────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: _tabs.length > 4,
                    tabs: _tabs.map((t) => Tab(text: t)).toList(),
                    labelColor: HearTechColors.deepTeal,
                    unselectedLabelColor: HearTechColors.textSecondary,
                    indicatorColor: HearTechColors.deepTeal,
                    indicatorWeight: 3,
                    labelStyle: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal),
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTab(tab, child)).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTab(String tab, ChildModel child) {
    switch (tab) {
      case 'Overview': return _OverviewTab(child: child, viewerRole: widget.viewerRole, childId: widget.childId);
      case 'Screenings': return _ScreeningsTab(childId: widget.childId, viewerRole: widget.viewerRole);
      case 'Referrals': return _ReferralsTab(childId: widget.childId, viewerRole: widget.viewerRole);
      case 'Notes': return _NotesTab(childId: widget.childId);
      case 'Speech': return _SpeechTab(childId: widget.childId, viewerRole: widget.viewerRole);
      case 'Observations': return _ObservationsTab(childId: widget.childId);
      default: return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB BAR DELEGATE
// ═══════════════════════════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: HearTechColors.background,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _OverviewTab extends ConsumerWidget {
  final ChildModel child;
  final String viewerRole;
  final String childId;
  const _OverviewTab({required this.child, required this.viewerRole, required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk gauge (HCW/Parent only, teacher sees limited info)
          if (viewerRole != 'teacher') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: HearTechDecorations.cardDecoration,
              child: Column(children: [
                Text('Risk Assessment', style: HearTechTextStyles.sectionHeader()),
                const SizedBox(height: 16),
                RiskGauge(score: child.riskScore, riskLevel: child.riskLevel, size: 140),
                const SizedBox(height: 12),
                Text(
                  child.riskLevel == 'high' ? 'High Risk — Referral Recommended'
                      : child.riskLevel == 'medium' ? 'Moderate Risk — Follow-up Needed'
                      : 'Low Risk — Normal Indicators',
                  style: HearTechTextStyles.subtitle(color: HearTechColors.riskColor(child.riskLevel)),
                ),
              ]),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          // Medical history (HCW/Parent only)
          if (viewerRole != 'teacher') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: HearTechDecorations.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Medical History', style: HearTechTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  _medRow('Premature Birth', child.medicalHistory.prematureBirth),
                  _medRow('NICU Admission', child.medicalHistory.nicuAdmission),
                  _medRow('Family Hearing Loss', child.medicalHistory.familyHistoryHearingLoss),
                  _infoRow('Ear Infections', '${child.medicalHistory.earInfectionCount}'),
                ],
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          // Handover Code (HCW only, only when parent not linked)
          if (viewerRole == 'hcw' && child.handoverCode != null && !child.isClaimed) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HearTechColors.warmOrange.withValues(alpha: 0.1),
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                Text('Share this code with the parent',
                    style: HearTechTextStyles.subtitle(color: HearTechColors.warmOrange)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(child.handoverCode!.code.length, (i) => Container(
                    width: 44, height: 56,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: HearTechColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.5)),
                    ),
                    child: Center(child: Text(child.handoverCode!.code[i],
                        style: HearTechTextStyles.handoverCode())),
                  ).animate(delay: (i * 80).ms).scale(
                    begin: const Offset(0, 0), end: const Offset(1, 1),
                    duration: 300.ms, curve: Curves.elasticOut,
                  )),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.timer_outlined, size: 16, color: HearTechColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    child.handoverCode!.isExpired ? 'EXPIRED'
                        : 'Expires ${DateFormat('MMM d, y • HH:mm').format(child.handoverCode!.expiresAt)}',
                    style: HearTechTextStyles.caption(
                      color: child.handoverCode!.isExpired ? HearTechColors.coralRed : HearTechColors.textSecondary,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: child.handoverCode!.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied!'), backgroundColor: HearTechColors.green),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Copy Code', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        final uid = ref.read(firebaseAuthServiceProvider).uid!;
                        final result = await ref.read(fastApiServiceProvider).regenerateHandoverCode(
                          childId: child.childId, hcwUid: uid,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('New code: ${result['newCode']}'), backgroundColor: HearTechColors.green),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text('Regenerate', style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)),
                  ),
                ]),
              ]),
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          // Linked Profiles
          if (viewerRole != 'parent') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: HearTechDecorations.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Linked Profiles', style: HearTechTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  _statusRow(Icons.family_restroom, 'Parent',
                      child.isClaimed ? 'Linked' : 'Not claimed',
                      child.isClaimed ? HearTechColors.green : HearTechColors.warmOrange),
                  _statusRow(Icons.school, 'Teacher',
                      child.hasTeacher ? 'Linked' : 'Not linked',
                      child.hasTeacher ? HearTechColors.green : HearTechColors.textSecondary),
                ],
              ),
            ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ] else ...[
            // Parent view of Linked Profiles (Cards for HCW & Teacher)
            _HcwInfoCard(childId: childId, hcwIds: child.hcwIds),
            const SizedBox(height: 16),
            _TeacherInfoCard(childId: childId, teacherIds: child.teacherIds, canLink: child.canLinkTeacher),
            const SizedBox(height: 16),
          ],

          // Screening history chart (HCW and Parent)
          if (viewerRole != 'teacher') ...[
            _ScreeningChart(childId: childId),
            const SizedBox(height: 16),
          ],

          // Teacher View: HCW Notes
          if (viewerRole == 'teacher') ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: HearTechDecorations.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HCW Clinical Notes', style: HearTechTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                  // Placeholder for dynamic fetching of notes that have isTeacherVisible
                  Text('No public notes currently shared by the healthcare worker.', 
                      style: HearTechTextStyles.caption()),
                ],
              ),
            ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          // Action buttons
          if (viewerRole == 'hcw') ...[
            HearTechButton(label: 'New Screening', onPressed: () => context.go(Routes.hcwNewScreening), icon: Icons.add),
            const SizedBox(height: 10),
            if (child.riskLevel == 'high')
              HearTechButton(label: 'Generate Referral', onPressed: () => _generateReferral(context, ref, child),
                  isSecondary: true, icon: Icons.description_outlined),
          ],
          if (viewerRole == 'parent' && child.canLinkTeacher && !child.hasTeacher) ...[
            // Button moved into _TeacherInfoCard
          ],
          if (viewerRole == 'teacher') ...[
            HearTechButton(label: 'Submit Observation', icon: Icons.edit_note,
                onPressed: () => context.go(Routes.teacherObservation)),
            const SizedBox(height: 12),
            HearTechButton(
              label: 'Unlink from Student', 
              icon: Icons.person_remove,
              isSecondary: true, 
              onPressed: () => _unlinkTeacher(context, ref),
            ),
          ],
          const SizedBox(height: 24),
          const DisclaimerFooter(),
        ],
      ),
    );
  }

  Future<void> _unlinkTeacher(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink from Student?'),
        content: const Text('You will lose access to this student profile.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Unlink', style: TextStyle(color: HearTechColors.coralRed))
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(fastApiServiceProvider).removeTeacher(childId: childId, teacherUid: ref.read(currentFirebaseUserProvider)?.uid ?? '');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlinked from student')));
          context.go(Routes.teacherDashboard);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _generateReferral(BuildContext context, WidgetRef ref, ChildModel child) async {
    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final fs = ref.read(firestoreServiceProvider);
      final screenings = await fs.getScreenings(childId);
      if (screenings.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No screening data to generate referral.')),
          );
        }
        return;
      }
      final user = await fs.getUser(ref.read(firebaseAuthServiceProvider).uid!);
      
      await fastApi.generateReferral(
        childId: childId, 
        screeningId: screenings.first.screeningId,
        riskScore: screenings.first.riskScore,
        answers: screenings.first.answers.map((a) => a.toJson()).toList(),
        hcwDescription: screenings.first.clinicalNote ?? 'No clinical note provided.',
        hcwInfo: user?.toJson() ?? {'name': 'Unknown HCW', 'role': 'hcw'},
        childInfo: {
          'name': child.name,
          'age': child.ageString,
          'gender': child.gender,
          'medicalHistory': child.medicalHistory.toJson()
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral generated!'), backgroundColor: HearTechColors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
  }

  Widget _medRow(String label, bool value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(value ? Icons.check_circle : Icons.cancel, size: 18,
          color: value ? HearTechColors.warmOrange : HearTechColors.green),
      const SizedBox(width: 10),
      Text(label, style: HearTechTextStyles.body()),
    ]),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      const Icon(Icons.info_outline, size: 18, color: HearTechColors.deepTeal),
      const SizedBox(width: 10),
      Text('$label: $value', style: HearTechTextStyles.body()),
    ]),
  );

  Widget _statusRow(IconData icon, String label, String status, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Text(label, style: HearTechTextStyles.body()),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(status, style: HearTechTextStyles.caption(color: color).copyWith(fontWeight: FontWeight.w600)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCREENINGS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ScreeningsTab extends ConsumerWidget {
  final String childId;
  final String viewerRole;
  const _ScreeningsTab({required this.childId, required this.viewerRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamScreenings(childId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingIndicator();
        final screenings = snap.data ?? [];
        if (screenings.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.assignment_outlined, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No screenings recorded yet.', style: HearTechTextStyles.subtitle()),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: screenings.length,
          separatorBuilder: (_, i) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final s = screenings[i];
            final riskColor = HearTechColors.riskColor(s.riskLevel);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: HearTechDecorations.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 4, height: 40,
                        decoration: BoxDecoration(color: riskColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('MMM d, yyyy • HH:mm').format(s.date), style: HearTechTextStyles.subtitle()),
                      const SizedBox(height: 2),
                      Text('By: ${s.conductorRole.toUpperCase()} • Bracket ${s.ageBracket}',
                          style: HearTechTextStyles.caption()),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: riskColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(viewerRole == 'teacher' ? s.riskLevel.toUpperCase() : '${s.riskScore}% ${s.riskLevel.toUpperCase()}',
                          style: HearTechTextStyles.caption(color: riskColor).copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  if (s.clinicalNote != null && s.clinicalNote!.isNotEmpty && viewerRole == 'hcw') ...[
                    const SizedBox(height: 8),
                    const Divider(),
                    Text('Note: ${s.clinicalNote}', style: HearTechTextStyles.caption()),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REFERRALS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ReferralsTab extends ConsumerWidget {
  final String childId;
  final String viewerRole;
  const _ReferralsTab({required this.childId, required this.viewerRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamReferrals(childId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingIndicator();
        final referrals = snap.data ?? [];
        if (referrals.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.description_outlined, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No referrals generated yet.', style: HearTechTextStyles.subtitle()),
            if (viewerRole == 'hcw') ...[
              const SizedBox(height: 8),
              Text('Generate a referral from the Overview tab.', style: HearTechTextStyles.caption()),
            ]
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: referrals.length,
          separatorBuilder: (_, i) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final r = referrals[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: HearTechDecorations.cardDecoration,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HearTechColors.coralRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: HearTechColors.coralRed),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Referral ${r.referralId.substring(0, 8).toUpperCase()}', style: HearTechTextStyles.subtitle()),
                  Text(DateFormat('MMM d, yyyy').format(r.generatedAt), style: HearTechTextStyles.caption()),
                  Text('Status: GENERATED', style: HearTechTextStyles.caption(
                      color: r.pdfCloudinaryUrl != null ? HearTechColors.green : HearTechColors.warmOrange)),
                ])),
                IconButton(
                  icon: const Icon(Icons.download, color: HearTechColors.deepTeal),
                  onPressed: () {
                    // It uses referral_preview_screen mapped in app_router under childId
                    context.go(Routes.referralPreview
                        .replaceFirst(':childId', childId)
                        .replaceFirst(':referralId', r.referralId));
                  },
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTES TAB (HCW — with visibility toggles)
// ═══════════════════════════════════════════════════════════════════════════════

class _NotesTab extends ConsumerStatefulWidget {
  final String childId;
  const _NotesTab({required this.childId});

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _noteCtrl = TextEditingController();
  bool _isPublic = false;
  bool _isTeacherVisible = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final user = ref.read(userProfileProvider);
      final noteId = fs.generateId(FirestorePaths.notes(widget.childId));

      final note = NoteModel(
        noteId: noteId,
        authorUid: user?.uid ?? '',
        authorName: user?.name ?? 'Unknown',
        authorRole: user?.role ?? 'hcw',
        text: _noteCtrl.text.trim(),
        isPublic: _isPublic,
        isTeacherVisible: _isTeacherVisible,
        createdAt: DateTime.now(),
      );
      await fs.addNote(widget.childId, note);

      // Fire PAR-02 notification if isPublic
      if (_isPublic) {
        try {
          final child = await fs.getChild(widget.childId);
          if (child != null && child.parentId != null && child.parentId!.isNotEmpty) {
            await ref.read(fastApiServiceProvider).sendNotification(
              uid: child.parentId!,
              type: 'PAR-02',
              title: 'New Note from HCW',
              body: '${user?.name ?? 'Your HCW'} added a note about ${child.name}.',
              relatedChildId: widget.childId,
            );
          }
        } catch (_) {}
      }

      // Fire TCH-04 notification if isTeacherVisible
      if (_isTeacherVisible) {
        try {
          final child = await fs.getChild(widget.childId);
          if (child != null && child.teacherIds.isNotEmpty) {
            for (final tid in child.teacherIds) {
              await ref.read(fastApiServiceProvider).sendNotification(
                uid: tid,
                type: 'TCH-04',
                title: 'New Note Shared',
                body: 'A clinical note has been shared with you about ${child.name}.',
                relatedChildId: widget.childId,
              );
            }
          }
        } catch (_) {}
      }

      if (mounted) {
        _noteCtrl.clear();
        setState(() { _isPublic = false; _isTeacherVisible = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved.'), backgroundColor: HearTechColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Clinical Note', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Type note...',
              filled: true, fillColor: HearTechColors.paleTeal,
              border: OutlineInputBorder(borderRadius: HearTechDecorations.inputBorderRadius, borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Checkbox(value: _isPublic, onChanged: (v) => setState(() => _isPublic = v ?? false),
                activeColor: HearTechColors.deepTeal),
            const Text('Visible to Parent'),
            const SizedBox(width: 16),
            Checkbox(value: _isTeacherVisible, onChanged: (v) => setState(() => _isTeacherVisible = v ?? false),
                activeColor: HearTechColors.purple),
            const Text('Visible to Teacher'),
          ]),
          const SizedBox(height: 12),
          HearTechButton(
            label: _isSaving ? 'Saving...' : 'Save Note',
            onPressed: _isSaving ? null : _saveNote,
          ),
          const SizedBox(height: 24),
          Text('Previous Notes', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),

          StreamBuilder(
            stream: firestoreService.streamNotes(widget.childId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
              }
              final notes = snap.data ?? [];
              if (notes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Center(child: Text('No notes yet.', style: HearTechTextStyles.caption())),
                );
              }
              return Column(
                children: notes.map((note) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: HearTechDecorations.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          AvatarCircle(name: note.authorName, radius: 16),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(note.authorName, style: HearTechTextStyles.subtitle()),
                              Text(DateFormat('MMM d, yyyy • HH:mm').format(note.createdAt),
                                  style: HearTechTextStyles.caption()),
                            ],
                          )),
                        ]),
                        const SizedBox(height: 10),
                        Text(note.text, style: HearTechTextStyles.body()),
                        const SizedBox(height: 8),
                        Row(children: [
                          _VisibilityChip(
                            label: 'Parent',
                            active: note.isPublic,
                            color: HearTechColors.deepTeal,
                            onTap: () {
                              firestoreService.updateNoteVisibility(
                                widget.childId, note.noteId, isPublic: !note.isPublic,
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _VisibilityChip(
                            label: 'Teacher',
                            active: note.isTeacherVisible,
                            color: HearTechColors.purple,
                            onTap: () {
                              firestoreService.updateNoteVisibility(
                                widget.childId, note.noteId, isTeacherVisible: !note.isTeacherVisible,
                              );
                            },
                          ),
                        ]),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _VisibilityChip({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : HearTechColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : HearTechColors.textSecondary.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(active ? Icons.visibility : Icons.visibility_off, size: 14,
              color: active ? color : HearTechColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: HearTechTextStyles.caption(color: active ? color : HearTechColors.textSecondary)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEECH LOGS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeechTab extends ConsumerWidget {
  final String childId;
  final String viewerRole;
  const _SpeechTab({required this.childId, required this.viewerRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamSpeechLogs(childId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingIndicator();
        final logs = snap.data ?? [];
        
        return Column(
          children: [
            // Only parents and teachers can start speech sessions
            if (viewerRole != 'hcw')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: HearTechButton(
                  label: 'Start Speech Session',
                  icon: Icons.mic,
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Select Speech Game', style: HearTechTextStyles.sectionHeader()),
                            const SizedBox(height: 20),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: HearTechColors.paleTeal, borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.record_voice_over, color: HearTechColors.deepTeal),
                              ),
                              title: Text('Show and Tell', style: HearTechTextStyles.subtitle()),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(ctx);
                                context.go(Routes.showAndTell.replaceFirst(':childId', childId));
                              },
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: HearTechColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.hearing, color: HearTechColors.purple),
                              ),
                              title: Text('Ling Six Test', style: HearTechTextStyles.subtitle()),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.pop(ctx);
                                context.go(Routes.lingSix.replaceFirst(':childId', childId));
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            
            Expanded(
              child: logs.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.mic_none, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
                    const SizedBox(height: 12),
                    Text('No speech sessions recorded.', style: HearTechTextStyles.subtitle()),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: logs.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final log = logs[i];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: HearTechDecorations.cardDecoration,
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(log.game == 'show_and_tell' ? Icons.record_voice_over : Icons.hearing,
                                color: HearTechColors.deepTeal),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.game == 'show_and_tell' ? 'Show & Tell' : 'Ling Six',
                                style: HearTechTextStyles.subtitle()),
                            Text(DateFormat('MMM d, yyyy').format(log.date), style: HearTechTextStyles.caption()),
                            Text('Score: ${log.score}%', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                          ])),
                        ]),
                      );
                    },
                  ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// OBSERVATIONS TAB (Teacher)
// ═══════════════════════════════════════════════════════════════════════════════

class _ObservationsTab extends ConsumerWidget {
  final String childId;
  const _ObservationsTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamTeacherObservations(childId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingIndicator();
        final obs = snap.data ?? [];
        if (obs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.visibility_outlined, size: 56, color: HearTechColors.purple.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No observations recorded.', style: HearTechTextStyles.subtitle()),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: obs.length,
          separatorBuilder: (_, i) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final o = obs[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HearTechColors.white,
                borderRadius: HearTechDecorations.cardBorderRadius,
                boxShadow: HearTechDecorations.cardShadow,
                border: Border(left: BorderSide(color: HearTechColors.purple, width: 4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('MMM d, yyyy').format(o.date), style: HearTechTextStyles.subtitle()),
                const SizedBox(height: 4),
                if (o.openNote != null && o.openNote!.isNotEmpty)
                  Text(o.openNote!, style: HearTechTextStyles.caption()),
                const SizedBox(height: 4),
                Text('${o.answers.length} questions answered', style: HearTechTextStyles.caption(color: HearTechColors.purple)),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PARENT CARDS & CHARTS
// ═══════════════════════════════════════════════════════════════════════════════

class _HcwInfoCard extends ConsumerStatefulWidget {
  final String childId;
  final List<String> hcwIds;
  const _HcwInfoCard({required this.childId, required this.hcwIds});

  @override
  ConsumerState<_HcwInfoCard> createState() => _HcwInfoCardState();
}

class _HcwInfoCardState extends ConsumerState<_HcwInfoCard> {
  bool _isLoading = false;

  Future<void> _removeHcw(String primaryHcwId, String hcwName) async {
    // Confirm dialog per spec
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Remove HCW?', style: HearTechTextStyles.sectionHeader()),
        content: Text(
          'Are you sure? This will remove Dr. $hcwName from your child\'s profile.',
          style: HearTechTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: HearTechTextStyles.button(color: HearTechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: HearTechTextStyles.button(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fastApiServiceProvider).removeHcw(
        childId: widget.childId,
        hcwId: primaryHcwId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HCW removed successfully'), backgroundColor: HearTechColors.green),
        );
        context.go(Routes.parentDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hcwIds.isEmpty) return const SizedBox.shrink();
    final primaryHcwId = widget.hcwIds[0];

    return FutureBuilder<UserModel?>(
      future: ref.read(firestoreServiceProvider).getUser(primaryHcwId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final hcw = snap.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Healthcare Worker', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            Row(children: [
              AvatarCircle(name: hcw.name, photoUrl: hcw.profilePhotoUrl, radius: 24),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hcw.name, style: HearTechTextStyles.subtitle()),
                Text('${hcw.title} • ${hcw.hospitalName ?? "Unknown Hospital"}', style: HearTechTextStyles.caption()),
              ])),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: () => _removeHcw(primaryHcwId, hcw.name),
                      child: Text('Remove HCW',
                          style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }
}

class _TeacherInfoCard extends ConsumerStatefulWidget {
  final String childId;
  final List<String> teacherIds;
  final bool canLink;
  const _TeacherInfoCard({required this.childId, required this.teacherIds, required this.canLink});

  @override
  ConsumerState<_TeacherInfoCard> createState() => _TeacherInfoCardState();
}

class _TeacherInfoCardState extends ConsumerState<_TeacherInfoCard> {
  bool _isLoading = false;

  Future<void> _removeTeacher() async {
    if (widget.teacherIds.isEmpty) return;

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Remove Teacher?', style: HearTechTextStyles.sectionHeader()),
        content: Text(
          'This will remove the teacher from your child\'s profile. They will lose access.',
          style: HearTechTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: HearTechTextStyles.button(color: HearTechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: HearTechTextStyles.button(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fastApiServiceProvider).removeTeacher(
        childId: widget.childId,
        teacherUid: widget.teacherIds.first,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher removed successfully'), backgroundColor: HearTechColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.teacherIds.isEmpty) {
      // Show invite button if child is 3+, otherwise explain why
      if (!widget.canLink) {
        // Child is under 3 — show info message
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HearTechColors.purple.withValues(alpha: 0.05),
            borderRadius: HearTechDecorations.cardBorderRadius,
            border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            const Icon(Icons.school_outlined, size: 32, color: HearTechColors.textSecondary),
            const SizedBox(height: 10),
            Text('Teacher linking is available when your child turns 3.',
                style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ).animate().fadeIn(duration: 300.ms);
      }

      // Child is 3+ — show invite button
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HearTechColors.purple.withValues(alpha: 0.08),
          borderRadius: HearTechDecorations.cardBorderRadius,
          border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          const Icon(Icons.school, size: 36, color: HearTechColors.purple),
          const SizedBox(height: 12),
          Text('Invite a teacher to support your child\'s development',
              style: HearTechTextStyles.body(color: HearTechColors.purple),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          HearTechButton(
            label: 'Invite Teacher',
            icon: Icons.person_add,
            onPressed: () => context.go(Routes.parentInviteTeacher.replaceFirst(':childId', widget.childId)),
            backgroundColor: HearTechColors.purple,
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms);
    }

    final primaryTeacherId = widget.teacherIds[0];
    return FutureBuilder<UserModel?>(
      future: ref.read(firestoreServiceProvider).getUser(primaryTeacherId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final teacher = snap.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('School Teacher', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            Row(children: [
              AvatarCircle(name: teacher.name, photoUrl: teacher.profilePhotoUrl, radius: 24),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(teacher.name, style: HearTechTextStyles.subtitle()),
                Text(teacher.schoolName ?? 'Unknown School', style: HearTechTextStyles.caption()),
              ])),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _removeTeacher,
                      child: Text('Remove Teacher',
                          style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
            ),
          ]),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }
}

class _ScreeningChart extends ConsumerWidget {
  final String childId;
  const _ScreeningChart({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamScreenings(childId),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final allScreenings = snap.data!;
        if (allScreenings.isEmpty) return const SizedBox.shrink();

        // Sort chronological
        allScreenings.sort((a, b) => a.date.compareTo(b.date));
        // Take last 5
        final screenings = allScreenings.length > 5 
            ? allScreenings.sublist(allScreenings.length - 5) 
            : allScreenings;

        final lineBarsData = [
          LineChartBarData(
            spots: screenings.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.riskScore.toDouble());
            }).toList(),
            isCurved: true,
            color: HearTechColors.deepTeal,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Risk Score History', style: HearTechTextStyles.sectionHeader()),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 33,
                          getTitlesWidget: (val, meta) {
                            return Text('${val.toInt()}', style: HearTechTextStyles.caption().copyWith(fontSize: 10));
                          },
                          reservedSize: 30,
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (val, meta) {
                            if (val.toInt() >= 0 && val.toInt() < screenings.length) {
                              final date = screenings[val.toInt()].date;
                              return Text(DateFormat('M/d').format(date), style: HearTechTextStyles.caption().copyWith(fontSize: 10));
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 22,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (screenings.length - 1).toDouble() > 0 ? (screenings.length - 1).toDouble() : 1,
                    minY: 0,
                    maxY: 100,
                    lineBarsData: lineBarsData,
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: 33,
                          color: HearTechColors.green.withValues(alpha: 0.2),
                          strokeWidth: 33, // This creates the "band" effect for 0-33, roughly
                          label: HorizontalLineLabel(show: false),
                        ),
                        HorizontalLine(
                          y: 66,
                          color: HearTechColors.warmOrange.withValues(alpha: 0.2),
                          strokeWidth: 33,
                          label: HorizontalLineLabel(show: false),
                        ),
                        HorizontalLine(
                          y: 100,
                          color: HearTechColors.coralRed.withValues(alpha: 0.2),
                          strokeWidth: 34,
                          label: HorizontalLineLabel(show: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }
}
