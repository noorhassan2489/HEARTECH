import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../core/di/providers.dart';
import '../../../shared/widgets/risk_badge.dart';
import '../../../shared/models/child_model.dart';

class ChildProfileDashboard extends ConsumerStatefulWidget {
  final String childId;
  final String viewerRole; // 'hcw', 'parent', 'teacher'

  const ChildProfileDashboard({
    super.key,
    required this.childId,
    required this.viewerRole,
  });

  @override
  ConsumerState<ChildProfileDashboard> createState() => _ChildProfileDashboardState();
}

class _ChildProfileDashboardState extends ConsumerState<ChildProfileDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _tabs;
  ChildModel? _child;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = _getTabsForRole(widget.viewerRole);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadChild();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> _getTabsForRole(String role) {
    switch (role) {
      case 'hcw':
        return ['Overview', 'Screenings', 'Referrals', 'Notes', 'Speech Logs'];
      case 'teacher':
        return ['Overview', 'Observations', 'Speech Logs'];
      case 'parent':
      default:
        return ['Overview', 'Screenings', 'Speech Games', 'Referrals'];
    }
  }

  Future<void> _loadChild() async {
    final child = await ref.read(childRepositoryProvider).getChild(widget.childId);
    if (mounted) {
      setState(() {
        _child = child;
        _loading = false;
      });
    }
  }

  String _ageString(DateTime dob) {
    final now = DateTime.now();
    final months = (now.year - dob.year) * 12 + now.month - dob.month;
    if (months >= 24) return '${months ~/ 12} years, ${months % 12} months';
    return '$months months';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Child Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final child = _child;
    if (child == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Child Profile')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.accentCoral),
            const SizedBox(height: 16),
            Text('Child profile not found.', style: AppTheme.bodyText),
          ]),
        ),
      );
    }

    final riskColor = AppTheme.riskColor(child.riskLevel);
    final riskLabel = child.riskLevel.isNotEmpty
        ? child.riskLevel[0].toUpperCase() + child.riskLevel.substring(1)
        : 'Unknown';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Child Profile', style: AppTheme.heading2),
        centerTitle: true,
        actions: [
          if (widget.viewerRole == 'hcw')
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'referral') {
                  Navigator.pushNamed(context, AppRouter.referralPreview, arguments: {
                    'childId': child.childId,
                    'riskScore': child.riskScore,
                  });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'referral', child: Text('Generate Referral')),
                const PopupMenuItem(value: 'edit', child: Text('Edit Profile')),
              ],
            ),
          if (widget.viewerRole == 'parent')
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'invite-teacher') {
                  Navigator.pushNamed(context, AppRouter.inviteTeacher, arguments: {
                    'childId': child.childId,
                  });
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'invite-teacher', child: Text('Invite Teacher')),
                const PopupMenuItem(value: 'remove-hcw', child: Text('Remove HCW')),
              ],
            ),
          if (widget.viewerRole == 'teacher')
            PopupMenuButton<String>(
              onSelected: (val) {},
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'remove-self', child: Text('Remove Myself')),
              ],
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryTeal,
          indicatorWeight: 3,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: Column(
        children: [
          // ── Header Card ──
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPale,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: riskColor.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryTeal),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(child.name, style: AppTheme.heading1.copyWith(fontSize: 22)),
                      const SizedBox(height: 4),
                      Text(
                        '${_ageString(child.dob)} • ${child.gender}',
                        style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        RiskBadge(riskLevel: riskLabel),
                        const SizedBox(width: 8),
                        Text(
                          'Score: ${child.riskScore}',
                          style: AppTheme.caption.copyWith(color: riskColor, fontWeight: FontWeight.bold),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerColor),

          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) => _buildTabView(tab, child)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabView(String tabName, ChildModel child) {
    switch (tabName) {
      case 'Overview':
        return _OverviewTab(child: child, viewerRole: widget.viewerRole);
      case 'Screenings':
        return _ScreeningsTab(childId: child.childId);
      case 'Referrals':
        return _ReferralsTab(childId: child.childId);
      case 'Notes':
        return _NotesTab(childId: child.childId);
      case 'Speech Logs':
      case 'Speech Games':
        return _SpeechLogsTab(childId: child.childId, viewerRole: widget.viewerRole);
      case 'Observations':
        return _ObservationsTab(childId: child.childId);
      default:
        return Center(child: Text(tabName));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
//  OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════

class _OverviewTab extends StatelessWidget {
  final ChildModel child;
  final String viewerRole;

  const _OverviewTab({required this.child, required this.viewerRole});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Risk Score Gauge
        Center(
          child: SizedBox(
            width: 160, height: 160,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: child.riskScore / 100),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (ctx, value, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140, height: 140,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 12,
                        backgroundColor: AppTheme.dividerColor,
                        valueColor: AlwaysStoppedAnimation(AppTheme.riskColor(child.riskLevel)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${child.riskScore}', style: AppTheme.display.copyWith(
                        fontSize: 42,
                        color: AppTheme.riskColor(child.riskLevel),
                      )),
                      Text('Risk Score', style: AppTheme.caption),
                    ]),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Medical History
        if (viewerRole != 'teacher') ...[
          _SectionTitle('Medical History'),
          _InfoCard(
            icon: Icons.medical_services_outlined,
            items: [
              if (child.medicalHistory['prematureBirth'] == true) 'Premature Birth',
              if (child.medicalHistory['nicuAdmission'] == true) 'NICU Admission',
              if (child.medicalHistory['familyHistoryHearingLoss'] == true) 'Family History of Hearing Loss',
              'Ear Infections: ${child.medicalHistory['earInfectionCount'] ?? 0}',
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Linked Professionals
        _SectionTitle('Linked Professionals'),
        if (child.hcwIds.isNotEmpty)
          _ProfessionalTile(icon: Icons.local_hospital, label: 'Healthcare Worker', count: child.hcwIds.length),
        if (child.teacherIds.isNotEmpty)
          _ProfessionalTile(icon: Icons.school, label: 'Teacher', count: child.teacherIds.length),
        if (child.parentId != null && child.parentId!.isNotEmpty)
          _ProfessionalTile(icon: Icons.family_restroom, label: 'Parent/Guardian', count: 1),

        const SizedBox(height: 24),

        // Quick Actions
        if (viewerRole == 'parent') ...[
          ElevatedButton.icon(
            style: AppTheme.primaryButton,
            onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'parent', 'childId': child.childId}),
            icon: const Icon(Icons.hearing),
            label: const Text('Run Home Screening'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: AppTheme.secondaryButton,
            onPressed: () => Navigator.pushNamed(context, AppRouter.speechModules),
            icon: const Icon(Icons.record_voice_over),
            label: const Text('Speech Games'),
          ),
        ],

        if (viewerRole == 'teacher') ...[
          ElevatedButton.icon(
            style: AppTheme.primaryButton,
            onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'teacher', 'childId': child.childId}),
            icon: const Icon(Icons.edit_note),
            label: const Text('Submit Observation'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: AppTheme.secondaryButton,
            onPressed: () => Navigator.pushNamed(context, AppRouter.speechModules),
            icon: const Icon(Icons.record_voice_over),
            label: const Text('Start Speech Session'),
          ),
        ],

        // Disclaimer
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTheme.heading2),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final List<String> items;
  const _InfoCard({required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryPale, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary))),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  const _ProfessionalTile({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration,
      child: Row(children: [
        Icon(icon, color: AppTheme.primaryTeal, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: AppTheme.bodyText)),
        Text('$count', style: AppTheme.bodyText.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SCREENINGS TAB
// ═══════════════════════════════════════════════════════════════

class _ScreeningsTab extends ConsumerWidget {
  final String childId;
  const _ScreeningsTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screeningsStream = ref.read(screeningRepositoryProvider).childScreenings(childId);
    return StreamBuilder(
      stream: screeningsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final screenings = snapshot.data ?? [];
        if (screenings.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No screenings yet.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: screenings.length,
          itemBuilder: (ctx, i) {
            final s = screenings[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.description_outlined, color: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(DateFormat('MMM d, yyyy').format(s.date), style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${s.conductorRole.toUpperCase()} Screening', style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                      Text('Score: ${s.riskScore}', style: AppTheme.caption),
                    ]),
                  ),
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.riskColor(s.riskLevel)),
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

// ═══════════════════════════════════════════════════════════════
//  REFERRALS TAB
// ═══════════════════════════════════════════════════════════════

class _ReferralsTab extends ConsumerWidget {
  final String childId;
  const _ReferralsTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.childReferrals(childId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final referrals = snapshot.data ?? [];
        if (referrals.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.description_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No referrals generated yet.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: referrals.length,
          itemBuilder: (ctx, i) {
            final r = referrals[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Referral Letter', style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPale,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text((r['status'] ?? 'saved').toString().toUpperCase(), style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Generated ${r['generatedAt'] != null ? DateFormat('MMM d, yyyy').format((r['generatedAt'] as dynamic).toDate()) : 'N/A'}',
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('View PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryTeal,
                    side: const BorderSide(color: AppTheme.primaryTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  NOTES TAB (HCW only)
// ═══════════════════════════════════════════════════════════════

class _NotesTab extends StatelessWidget {
  final String childId;
  const _NotesTab({required this.childId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.note_alt_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text('Clinical notes will appear here.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: AppTheme.primaryTeal,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('Add Note', style: AppTheme.buttonText),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  SPEECH LOGS TAB
// ═══════════════════════════════════════════════════════════════

class _SpeechLogsTab extends ConsumerWidget {
  final String childId;
  final String viewerRole;
  const _SpeechLogsTab({required this.childId, required this.viewerRole});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.childSpeechLogs(childId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.record_voice_over_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No speech sessions yet.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
              if (viewerRole == 'parent' || viewerRole == 'teacher') ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  style: AppTheme.primaryButton.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(200, 48)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, AppRouter.speechModules),
                  child: const Text('Start Speech Game'),
                ),
              ],
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: logs.length,
          itemBuilder: (ctx, i) {
            final log = logs[i];
            final game = log['game'] ?? '';
            final score = log['score'] ?? 0;
            final icon = game == 'showAndTell' ? Icons.image : Icons.hearing;
            final label = game == 'showAndTell' ? 'Show & Tell' : 'Ling Six';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primaryPale, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppTheme.primaryTeal),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                  Text('Score: $score%', style: AppTheme.caption),
                ])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  OBSERVATIONS TAB (Teacher)
// ═══════════════════════════════════════════════════════════════

class _ObservationsTab extends ConsumerWidget {
  final String childId;
  const _ObservationsTab({required this.childId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    return StreamBuilder(
      stream: firestoreService.childTeacherObservations(childId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final obs = snapshot.data ?? [];
        if (obs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.assignment_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No classroom observations yet.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: AppTheme.primaryButton.copyWith(minimumSize: const WidgetStatePropertyAll(Size(200, 48))),
                onPressed: () => Navigator.pushNamed(context, AppRouter.newScreening, arguments: {'role': 'teacher', 'childId': childId}),
                child: const Text('Submit Observation'),
              ),
            ]),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: obs.length,
          itemBuilder: (ctx, i) {
            final o = obs[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Observation', style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (o['openNote'] != null)
                  Text(o['openNote'], style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
              ]),
            );
          },
        );
      },
    );
  }
}
