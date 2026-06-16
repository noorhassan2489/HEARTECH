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
import 'package:heartech/shared/widgets/handover_code_boxes.dart';
import 'package:heartech/shared/models/note_model.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/features/speech/utils/speech_game_picker.dart';
import 'package:heartech/features/referral/widgets/child_referrals_tab.dart';
import 'package:heartech/services/fastapi_service.dart';
import 'package:intl/intl.dart';

/// Child Profile Screen — tabbed interface per role.
/// HCW: Overview | Screenings | Referrals | Notes | Speech Logs
/// Parent: Overview | Screenings | Referrals | Notes | Speech Logs
/// Teacher: Overview | Observations | Speech Logs (limited data)
class ChildProfileScreen extends ConsumerStatefulWidget {
  final String childId;
  final String viewerRole; // hcw, parent, teacher
  final String? initialTab;

  const ChildProfileScreen({
    super.key,
    required this.childId,
    required this.viewerRole,
    this.initialTab,
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
        return ['Overview', 'Screenings', 'Referrals', 'Observations', 'Notes', 'Speech'];
      case 'parent':
        return ['Overview', 'Screenings', 'Referrals', 'Observations', 'Notes', 'Speech'];
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
    final tabName = widget.initialTab?.trim();
    if (tabName != null && tabName.isNotEmpty) {
      final normalized = tabName.toLowerCase();
      final index = _tabs.indexWhere((t) => t.toLowerCase() == normalized);
      if (index >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabController.animateTo(index);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildProfileUnavailableScaffold({
    required String message,
    String? subtitle,
  }) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        title: const Text('Child Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_backRoute),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: HearTechTextStyles.subtitle(color: HearTechColors.coralRed),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              HearTechButton(
                label: 'Back to Dashboard',
                onPressed: () => context.go(_backRoute),
              ),
            ],
          ),
        ),
      ),
    );
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
        if (childSnap.hasError) {
          return _buildProfileUnavailableScaffold(
            message: 'Could not load child profile.',
            subtitle: 'You may no longer have access to this profile.',
          );
        }
        final child = childSnap.data;
        if (child == null) {
          return _buildProfileUnavailableScaffold(
            message: 'Child profile not found.',
            subtitle: 'It may have been deleted or unlinked.',
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
      case 'Referrals':
        return ChildReferralsTab(
          childId: widget.childId,
          viewerRole: widget.viewerRole,
          child: child,
        );
      case 'Notes':
        if (widget.viewerRole == 'parent') {
          return _ParentNotesTab(childId: widget.childId, child: child);
        }
        return _NotesTab(childId: widget.childId, child: child);
      case 'Speech': return _SpeechTab(childId: widget.childId, viewerRole: widget.viewerRole);
      case 'Observations':
        return _ObservationsTab(
          childId: widget.childId,
          viewerRole: widget.viewerRole,
          child: child,
        );
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
                if (viewerRole == 'hcw') ...[
                  const SizedBox(height: 4),
                  Text(
                    'Combined milestone score (HCW + home + classroom + speech)',
                    style: HearTechTextStyles.caption(),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                RiskGauge(score: child.riskScore, riskLevel: child.riskLevel, size: 140),
                const SizedBox(height: 12),
                Text(
                  child.riskLevel == 'high' ? 'High Risk — Referral Recommended'
                      : child.riskLevel == 'medium' ? 'Moderate Risk — Follow-up Needed'
                      : 'Low Risk — Normal Indicators',
                  style: HearTechTextStyles.subtitle(color: HearTechColors.riskColor(child.riskLevel)),
                ),
                if (viewerRole == 'hcw' && child.riskBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: child.riskBreakdown.entries.map((entry) {
                      final label = switch (entry.key) {
                        'hcw' => 'HCW',
                        'parent' => 'Parent',
                        'teacher' => 'Teacher',
                        'speech' => 'Speech',
                        _ => entry.key,
                      };
                      final score = entry.value;
                      return Chip(
                        label: Text(
                          score != null ? '$label: $score%' : '$label: —',
                          style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
                        ),
                        backgroundColor: HearTechColors.paleTeal.withValues(alpha: 0.5),
                        side: BorderSide(color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
                      );
                    }).toList(),
                  ),
                ],
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
                HandoverCodeBoxes(code: child.handoverCode!.code),
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
            _HcwInfoCard(childId: childId, hcwIds: child.hcwIds, viewerRole: viewerRole),
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
            HearTechButton(
              label: 'Follow-up Screening',
              onPressed: () => context.go(Routes.hcwFollowUpScreeningFor(childId)),
              icon: Icons.refresh,
            ),
            const SizedBox(height: 10),
            HearTechButton(
              label: 'Clinical Assistant',
              onPressed: () => _openClinicalAssistant(context, ref, child),
              isSecondary: true,
              icon: Icons.medical_services_outlined,
            ),
            const SizedBox(height: 12),
            if (child.isClaimed)
              HearTechButton(
                label: 'Unlink from Profile',
                icon: Icons.person_remove,
                isSecondary: true,
                onPressed: () => _unlinkHcwSelf(context, ref, child),
              )
            else
              HearTechButton(
                label: 'Delete Child Profile',
                icon: Icons.delete_outline,
                isSecondary: true,
                onPressed: () => _deleteChildProfile(context, ref, child),
              ),
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

  Future<void> _unlinkHcwSelf(BuildContext context, WidgetRef ref, ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unlink from ${child.name}?'),
        content: Text(
          'You will lose access to ${child.name}\'s profile. The parent will keep the profile and can link another healthcare worker.',
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink', style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(fastApiServiceProvider).hcwUnlinkSelf(childId: childId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been unlinked from this profile.'),
            backgroundColor: HearTechColors.green,
          ),
        );
        context.go(Routes.hcwDashboard);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FastApiService.userFacingMessage(e)),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
  }

  Future<void> _deleteChildProfile(BuildContext context, WidgetRef ref, ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${child.name}\'s profile?'),
        content: Text(
          'This permanently deletes the profile, screenings, and handover code. '
          'This cannot be undone. Only use this if the profile was created by mistake.',
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(fastApiServiceProvider).hcwDeleteChild(childId: childId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Child profile deleted.'),
            backgroundColor: HearTechColors.green,
          ),
        );
        context.go(Routes.hcwDashboard);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(FastApiService.userFacingMessage(e)),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
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

  Future<void> _openClinicalAssistant(BuildContext context, WidgetRef ref, ChildModel child) async {
    context.push(Routes.referralChat.replaceFirst(':childId', childId));
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
// NOTES TAB (Parent — read-only, HCW notes marked public)
// ═══════════════════════════════════════════════════════════════════════════════

class _ParentNotesTab extends ConsumerStatefulWidget {
  final String childId;
  final ChildModel child;
  const _ParentNotesTab({required this.childId, required this.child});

  @override
  ConsumerState<_ParentNotesTab> createState() => _ParentNotesTabState();
}

class _ParentNotesTabState extends ConsumerState<_ParentNotesTab> {
  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);
    final parentUid = ref.read(firebaseAuthServiceProvider).uid ?? '';

    return RefreshIndicator(
      color: HearTechColors.deepTeal,
      onRefresh: () async {
        setState(() {});
      },
      child: ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text('From Healthcare Worker', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 4),
        Text(
          'Clinical notes your healthcare worker chose to share with you.',
          style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<NoteModel>>(
          stream: firestoreService.streamParentNotes(widget.childId, parentUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal)),
              );
            }
            if (snap.hasError) {
              return _emptyNotesCard('Could not load HCW notes. Try again.');
            }
            final notes = snap.data ?? [];
            if (notes.isEmpty) {
              return _emptyNotesCard('No notes from your healthcare worker yet.');
            }
            return Column(
              children: notes.map((note) => _noteCard(note, showHcwShare: false)).toList(),
            );
          },
        ),
        const SizedBox(height: 28),
        Text('From Teacher', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 4),
        Text(
          'Messages from your child\'s teacher. You can choose to share them with your HCW.',
          style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<NoteModel>>(
          stream: firestoreService.streamTeacherAuthoredNotes(widget.childId, parentUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal)),
              );
            }
            if (snap.hasError) {
              return _emptyNotesCard('Could not load teacher notes. Try again.');
            }
            final notes = snap.data ?? [];
            if (notes.isEmpty) {
              return _emptyNotesCard('No notes from the teacher yet.');
            }
            return Column(
              children: notes.map((note) {
                return _noteCard(
                  note,
                  showHcwShare: true,
                  hcwShareValue: note.isVisibleToHcw,
                  onHcwShareChanged: (share) {
                    firestoreService.updateNoteHcwShare(
                      widget.childId,
                      note.noteId,
                      share: share,
                      hcwIds: widget.child.hcwIds,
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
    );
  }

  Widget _emptyNotesCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: HearTechDecorations.cardDecoration,
      child: Text(message,
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
          textAlign: TextAlign.center),
    );
  }

  Widget _noteCard(
    NoteModel note, {
    required bool showHcwShare,
    bool hcwShareValue = false,
    ValueChanged<bool>? onHcwShareChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarCircle(name: note.authorName, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.authorName, style: HearTechTextStyles.subtitle()),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(note.createdAt),
                      style: HearTechTextStyles.caption(
                        color: HearTechColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(note.text, style: HearTechTextStyles.body()),
          if (showHcwShare && onHcwShareChanged != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.share_outlined, size: 18, color: HearTechColors.deepTeal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Share with HCW', style: HearTechTextStyles.caption()),
                ),
                Switch(
                  value: hcwShareValue,
                  activeThumbColor: HearTechColors.deepTeal,
                  onChanged: onHcwShareChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NOTES TAB (HCW — with visibility toggles)
// ═══════════════════════════════════════════════════════════════════════════════

class _NotesTab extends ConsumerStatefulWidget {
  final String childId;
  final ChildModel child;
  const _NotesTab({required this.childId, required this.child});

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _noteCtrl = TextEditingController();
  bool _isPublic = false;
  bool _isTeacherVisible = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Repair older notes missing denormalized sharing fields.
    Future.microtask(() {
      ref.read(firestoreServiceProvider).backfillNoteSharingFields(widget.childId);
    });
  }

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
      final child = await fs.getChild(widget.childId);
      final noteId = fs.generateId(FirestorePaths.notes(widget.childId));

      final note = NoteModel(
        noteId: noteId,
        authorUid: user?.uid ?? '',
        authorName: user?.name ?? 'Unknown',
        authorRole: user?.role ?? 'hcw',
        text: _noteCtrl.text.trim(),
        isPublic: _isPublic,
        isTeacherVisible: _isTeacherVisible,
        parentId: _isPublic ? child?.parentId : null,
        visibleToTeacherIds:
            _isTeacherVisible ? List<String>.from(child?.teacherIds ?? []) : const [],
        createdAt: DateTime.now(),
      );
      await fs.addNote(widget.childId, note);

      // Fire PAR-02 notification if isPublic
      if (_isPublic) {
        try {
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
            Checkbox(
              value: _isTeacherVisible,
              onChanged: widget.child.hasTeacher
                  ? (v) => setState(() => _isTeacherVisible = v ?? false)
                  : null,
              activeColor: HearTechColors.purple,
            ),
            Text(
              'Visible to Teacher',
              style: HearTechTextStyles.body(
                color: widget.child.hasTeacher
                    ? HearTechColors.textPrimary
                    : HearTechColors.textSecondary,
              ),
            ),
          ]),
          if (!widget.child.hasTeacher)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Link a teacher before sharing notes with them.',
                style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
              ),
            ),
          const SizedBox(height: 12),
          HearTechButton(
            label: _isSaving ? 'Saving...' : 'Save Note',
            onPressed: _isSaving ? null : _saveNote,
          ),
          const SizedBox(height: 24),
          Text('Your Notes', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),

          StreamBuilder(
            stream: firestoreService.streamHcwAuthoredNotes(widget.childId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
              }
              if (snap.hasError) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Center(
                    child: Text(
                      'Could not load notes.',
                      style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
                    ),
                  ),
                );
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
          const SizedBox(height: 24),
          Text('Shared by Parent (from Teacher)', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),
          StreamBuilder<List<NoteModel>>(
            stream: firestoreService.streamHcwSharedTeacherNotes(
              widget.childId,
              ref.read(firebaseAuthServiceProvider).uid ?? '',
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
              }
              if (snap.hasError) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Center(
                    child: Text(
                      'Could not load shared teacher notes.',
                      style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
                    ),
                  ),
                );
              }
              final notes = snap.data ?? [];
              if (notes.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Center(
                    child: Text(
                      'No teacher notes shared with you yet.',
                      style: HearTechTextStyles.caption(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return Column(
                children: notes.map((note) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HearTechColors.purple.withValues(alpha: 0.04),
                      borderRadius: HearTechDecorations.cardBorderRadius,
                      border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.authorName, style: HearTechTextStyles.subtitle(color: HearTechColors.purple)),
                        Text(DateFormat('MMM d, yyyy').format(note.createdAt),
                            style: HearTechTextStyles.caption()),
                        const SizedBox(height: 8),
                        Text(note.text, style: HearTechTextStyles.body()),
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
        if (snap.hasError) {
          return Center(
            child: Text(
              'Could not load speech sessions.',
              style: HearTechTextStyles.body(color: HearTechColors.coralRed),
            ),
          );
        }
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
                  onPressed: () => showSpeechGamePicker(context, childId),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  log.isShowAndTell ? Icons.record_voice_over : Icons.hearing,
                                  color: HearTechColors.deepTeal,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(log.gameDisplayName, style: HearTechTextStyles.subtitle()),
                                Text(DateFormat('MMM d, yyyy').format(log.date), style: HearTechTextStyles.caption()),
                                Text('Score: ${log.score}%', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                              ])),
                            ]),
                            if (viewerRole == 'hcw') ...[
                              const SizedBox(height: 10),
                              if (log.isShowAndTell) ...[
                                if (log.expectedWord?.isNotEmpty ?? false)
                                  Text('Word: ${log.expectedWord}', style: HearTechTextStyles.caption()),
                                if (log.whisperTranscript?.isNotEmpty ?? false)
                                  Text('Transcript: ${log.whisperTranscript}', style: HearTechTextStyles.caption()),
                                if (log.clarityRating?.isNotEmpty ?? false)
                                  Text('Clarity: ${log.clarityRating}', style: HearTechTextStyles.caption()),
                              ],
                              if (log.isLingSix && (log.frequencyFlag?.isNotEmpty ?? false))
                                Text(
                                  'Ling result: ${log.frequencyFlag!.toUpperCase()}',
                                  style: HearTechTextStyles.caption(color: HearTechColors.purple),
                                ),
                              if (log.aiAnalysisSummary?.isNotEmpty ?? false)
                                Text(log.aiAnalysisSummary!, style: HearTechTextStyles.caption()),
                            ] else ...[
                              if (log.isShowAndTell && (log.expectedWord?.isNotEmpty ?? false))
                                Text('Word: ${log.expectedWord}', style: HearTechTextStyles.caption()),
                            ],
                          ],
                        ),
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
  final String viewerRole;
  final ChildModel child;
  const _ObservationsTab({
    required this.childId,
    required this.viewerRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    final uid = ref.read(firebaseAuthServiceProvider).uid ?? '';

    Stream<List<TeacherObservationModel>> stream;
    if (viewerRole == 'hcw') {
      stream = firestoreService.streamHcwSharedObservations(childId, uid);
    } else if (viewerRole == 'teacher') {
      stream = firestoreService.streamTeacherOwnObservations(childId, uid);
    } else {
      stream = firestoreService.streamTeacherObservations(childId);
    }

    return StreamBuilder<List<TeacherObservationModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const LoadingIndicator();
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Could not load observations.',
              style: HearTechTextStyles.body(color: HearTechColors.coralRed),
            ),
          );
        }
        final obs = snap.data ?? [];

        if (obs.isEmpty) {
          final emptyMessage = viewerRole == 'hcw'
              ? 'No observations shared with you yet.\nParents control what you can see.'
              : viewerRole == 'parent'
                  ? 'No classroom observations yet.'
                  : 'No observations recorded.';
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined,
                    size: 56, color: HearTechColors.purple.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(emptyMessage,
                    style: HearTechTextStyles.subtitle(),
                    textAlign: TextAlign.center),
              ],
            ),
          );
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM d, yyyy').format(o.date),
                      style: HearTechTextStyles.subtitle()),
                  const SizedBox(height: 4),
                  if (o.openNote != null && o.openNote!.isNotEmpty)
                    Text(o.openNote!, style: HearTechTextStyles.body()),
                  const SizedBox(height: 4),
                  Text('${o.answers.length} questions answered',
                      style: HearTechTextStyles.caption(color: HearTechColors.purple)),
                  if (viewerRole == 'parent') ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.share_outlined,
                            size: 18, color: HearTechColors.deepTeal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Share with HCW',
                              style: HearTechTextStyles.caption()),
                        ),
                        Switch(
                          value: o.isVisibleToHcw,
                          activeThumbColor: HearTechColors.deepTeal,
                          onChanged: (share) {
                            firestoreService.updateObservationHcwShare(
                              childId,
                              o.obsId,
                              share: share,
                              hcwIds: child.hcwIds,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                  if (viewerRole == 'hcw' && o.isVisibleToHcw)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Shared by parent',
                          style: HearTechTextStyles.caption(
                              color: HearTechColors.deepTeal)),
                    ),
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
// PARENT CARDS & CHARTS
// ═══════════════════════════════════════════════════════════════════════════════

class _HcwInfoCard extends ConsumerStatefulWidget {
  final String childId;
  final List<String> hcwIds;
  final String viewerRole;
  const _HcwInfoCard({
    required this.childId,
    required this.hcwIds,
    required this.viewerRole,
  });

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
    if (widget.hcwIds.isEmpty) {
      if (widget.viewerRole != 'parent') return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HearTechColors.deepTeal.withValues(alpha: 0.08),
          borderRadius: HearTechDecorations.cardBorderRadius,
          border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          const Icon(Icons.medical_services_outlined, size: 36, color: HearTechColors.deepTeal),
          const SizedBox(height: 12),
          Text(
            'Link a healthcare worker to continue clinical care and screenings',
            style: HearTechTextStyles.body(color: HearTechColors.deepTeal),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          HearTechButton(
            label: 'Invite Healthcare Worker',
            icon: Icons.person_add,
            onPressed: () => context.go(
              Routes.parentInviteHcw.replaceFirst(':childId', widget.childId),
            ),
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms);
    }

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
            if (widget.viewerRole == 'parent')
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
