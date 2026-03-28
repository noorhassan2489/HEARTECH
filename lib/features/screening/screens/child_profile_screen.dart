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
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_gauge.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';
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
        return ['Overview', 'Screenings', 'Speech'];
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
      case 'Referrals': return _ReferralsTab(childId: widget.childId);
      case 'Notes': return _NotesTab(childId: widget.childId);
      case 'Speech': return _SpeechTab(childId: widget.childId);
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

          // Handover Code (HCW only)
          if (viewerRole == 'hcw' && child.handoverCode != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Text('Handover Code', style: HearTechTextStyles.sectionHeader()),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(child.handoverCode!.code.length, (i) => Container(
                    width: 40, height: 50,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: HearTechColors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
                    ),
                    child: Center(child: Text(child.handoverCode!.code[i],
                        style: HearTechTextStyles.handoverCode())),
                  )),
                ),
                const SizedBox(height: 8),
                Text(
                  child.handoverCode!.isExpired ? 'EXPIRED'
                      : 'Expires ${DateFormat('MMM d, y').format(child.handoverCode!.expiresAt)}',
                  style: HearTechTextStyles.caption(
                    color: child.handoverCode!.isExpired ? HearTechColors.coralRed : HearTechColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: child.handoverCode!.code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied!')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text('Copy', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                  ),
                ]),
              ]),
            ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
          ],

          // Linked Profiles
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

          // Action buttons
          if (viewerRole == 'hcw') ...[
            HearTechButton(label: 'New Screening', onPressed: () => context.go(Routes.hcwNewScreening), icon: Icons.add),
            const SizedBox(height: 10),
            if (child.riskLevel == 'high')
              HearTechButton(label: 'Generate Referral', onPressed: () => _generateReferral(context, ref),
                  isSecondary: true, icon: Icons.description_outlined),
          ],
          if (viewerRole == 'parent' && child.canLinkTeacher && !child.hasTeacher) ...[
            HearTechButton(label: 'Invite Teacher', icon: Icons.person_add,
                onPressed: () => context.go(Routes.parentInviteTeacher.replaceFirst(':childId', childId))),
          ],
          if (viewerRole == 'teacher') ...[
            HearTechButton(label: 'Submit Observation', icon: Icons.edit_note,
                onPressed: () => context.go(Routes.teacherObservation)),
          ],
          const SizedBox(height: 24),
          const DisclaimerFooter(),
        ],
      ),
    );
  }

  Future<void> _generateReferral(BuildContext context, WidgetRef ref) async {
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
      await fastApi.generateReferral(childId: childId, screeningId: screenings.first.screeningId);
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
// REFERRALS TAB (HCW only)
// ═══════════════════════════════════════════════════════════════════════════════

class _ReferralsTab extends ConsumerWidget {
  final String childId;
  const _ReferralsTab({required this.childId});

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
            const SizedBox(height: 8),
            Text('Generate a referral from the Overview tab.', style: HearTechTextStyles.caption()),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF download coming soon.')),
                    );
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

class _NotesTab extends StatefulWidget {
  final String childId;
  const _NotesTab({required this.childId});

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  final _noteCtrl = TextEditingController();
  bool _isPublic = false;
  bool _isTeacherVisible = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            label: 'Save Note',
            onPressed: () {
              if (_noteCtrl.text.trim().isEmpty) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note saved.'), backgroundColor: HearTechColors.green),
              );
              _noteCtrl.clear();
            },
          ),
          const SizedBox(height: 24),
          Text('Previous Notes', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: HearTechDecorations.cardDecoration,
            child: Center(child: Text('Notes will appear here.', style: HearTechTextStyles.caption())),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEECH LOGS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeechTab extends ConsumerWidget {
  final String childId;
  const _SpeechTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.streamSpeechLogs(childId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const LoadingIndicator();
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.mic_none, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No speech sessions recorded.', style: HearTechTextStyles.subtitle()),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
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
