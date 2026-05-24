import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

class LingSixScreen extends ConsumerStatefulWidget {
  final String childId;
  const LingSixScreen({super.key, required this.childId});
  @override
  ConsumerState<LingSixScreen> createState() => _LingSixScreenState();
}

class _LingSixScreenState extends ConsumerState<LingSixScreen> {
  // 0=intro, 1=testing, 2=roundBreak, 3=submitting, 4=result
  int _phase = 0;
  int _round = 1;
  bool _isPlayingSound = false;
  bool _isSaving = false;
  late final AudioPlayer _audioPlayer;

  final _sounds = const [
    {'sound': 'm', 'display': '/m/', 'freq': '250-500 Hz', 'label': 'Low frequency'},
    {'sound': 'ah', 'display': '/ah/', 'freq': '500-1000 Hz', 'label': 'Low-mid'},
    {'sound': 'oo', 'display': '/oo/', 'freq': '500-1000 Hz', 'label': 'Mid'},
    {'sound': 'ee', 'display': '/ee/', 'freq': '1000-3000 Hz', 'label': 'Mid-high'},
    {'sound': 'sh', 'display': '/sh/', 'freq': '2000-4000 Hz', 'label': 'High'},
    {'sound': 's', 'display': '/s/', 'freq': '4000-8000 Hz', 'label': 'Very high'},
  ];

  // null = not answered yet
  final Map<int, bool?> _round1 = {};
  final Map<int, bool?> _round2 = {};
  Map<int, bool?> get _current => _round == 1 ? _round1 : _round2;

  // API result
  Map<String, dynamic>? _apiResult;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  int get _answeredCount => _current.values.where((v) => v != null).length;
  bool get _allAnswered => _answeredCount == 6;

  Future<void> _playSound(int index) async {
    setState(() => _isPlayingSound = true);
    try {
      final name = _sounds[index]['sound'];
      await _audioPlayer.setAsset('assets/sounds/ling_$name.mp3');
      await _audioPlayer.play();
      await _audioPlayer.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed);
    } catch (_) {
      // Asset may not exist yet — simulate
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (mounted) setState(() => _isPlayingSound = false);
  }

  void _respond(int index, bool heard) {
    setState(() => _current[index] = heard);
  }

  void _completeRound1() {
    setState(() => _phase = 2);
  }

  void _startRound2() {
    setState(() { _round = 2; _phase = 1; });
  }

  Future<void> _submit() async {
    setState(() => _phase = 3);
    try {
      final api = ref.read(fastApiServiceProvider);
      final results = List.generate(6, (i) => {
        'sound': _sounds[i]['sound'],
        'round1heard': _round1[i] ?? false,
        'round2heard': _round2[i] ?? false,
      });
      _apiResult = await api.analyzeLingSix(results: results, childId: widget.childId);
    } catch (e) {
      _apiResult = {
        'overallResult': 'Error', 'frequencyRangeEstimate': '',
        'flaggedSounds': [], 'clinicalExplanation': 'Analysis failed: $e',
        'recommendation': 'Please try again.',
      };
    }
    if (mounted) setState(() => _phase = 4);
  }

  Future<void> _saveResult() async {
    setState(() => _isSaving = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final role = ref.read(userRoleProvider) ?? 'parent';
      final logId = fs.generateId('speechLogs');
      final r2Heard = _round2.values.where((v) => v == true).length;
      final score = (r2Heard / 6 * 100).round();

      final lingResults = List.generate(6, (i) => LingSixResult(
        sound: _sounds[i]['sound']!,
        round1heard: _round1[i] ?? false,
        round2heard: _round2[i] ?? false,
      ));

      final log = SpeechLogModel(
        logId: logId, game: 'lingSix', conductedBy: uid, conductorRole: role,
        date: DateTime.now(), score: score, lingResults: lingResults,
        frequencyFlag: _apiResult?['frequencyRangeEstimate'] as String?,
        aiAnalysisSummary: _apiResult?['clinicalExplanation'] as String?,
      );
      await fs.addSpeechLog(widget.childId, log);
      await fs.updateChild(widget.childId, {'lastSpeechSessionDate': DateTime.now()});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result saved! ✓'), backgroundColor: HearTechColors.green));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: HearTechColors.coralRed));
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: HearTechColors.deepTeal,
        leading: IconButton(icon: const Icon(Icons.close, color: HearTechColors.white),
          onPressed: () => context.pop()),
        title: Text('Ling Six Sound Test',
          style: HearTechTextStyles.appBarTitle(color: HearTechColors.white)),
        centerTitle: true,
        actions: [
          if (_phase == 1)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HearTechColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(
                'Round $_round • ${_round == 1 ? "1m" : "3m"}',
                style: HearTechTextStyles.caption(color: HearTechColors.white)
                    .copyWith(fontWeight: FontWeight.w700))),
            ),
        ],
      ),
      body: SafeArea(child: _buildPhase()),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case 0: return _buildIntro();
      case 1: return _buildTesting();
      case 2: return _buildRoundBreak();
      case 3: return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
      case 4: return _buildResult();
      default: return const SizedBox();
    }
  }

  // ── Intro ──────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: HearTechColors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.hearing, size: 64, color: HearTechColors.purple),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text('Ling Six Sound Test', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 12),
        Text('Test if your child can hear 6 key speech sounds across different frequencies.',
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: HearTechColors.paleTeal, borderRadius: HearTechDecorations.cardBorderRadius),
          child: Column(children: [
            _infoRow(Icons.straighten, 'Round 1: Child 1 metre away', HearTechColors.deepTeal),
            const SizedBox(height: 10),
            _infoRow(Icons.straighten, 'Round 2: Child 3 metres away', HearTechColors.purple),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HearTechColors.warmOrange.withValues(alpha: 0.08),
            borderRadius: HearTechDecorations.cardBorderRadius),
          child: Row(children: [
            const Icon(Icons.info_outline, color: HearTechColors.warmOrange, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Quiet room. Say each sound without showing your lips.',
              style: HearTechTextStyles.caption(color: HearTechColors.warmOrange))),
          ]),
        ),
        const SizedBox(height: 32),
        HearTechButton(label: 'Begin Test', onPressed: () => setState(() => _phase = 1)),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: HearTechTextStyles.body())),
    ]);
  }

  // ── Testing ────────────────────────────────────────────────────────────
  Widget _buildTesting() {
    return Column(children: [
      // Distance banner
      Container(
        width: double.infinity, padding: const EdgeInsets.all(12),
        color: HearTechColors.warmOrange.withValues(alpha: 0.15),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.straighten, color: HearTechColors.warmOrange, size: 18),
          const SizedBox(width: 8),
          Text(_round == 1
            ? 'Child should be 1 metre away from the device'
            : 'Move the child 3 metres away from the device',
            style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)
                .copyWith(fontWeight: FontWeight.w600)),
        ]),
      ),

      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: 6,
        itemBuilder: (_, i) => _buildSoundCard(i),
      )),

      // Progress + button
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(children: [
        // Progress dots
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(6, (i) {
          final answered = _current[i] != null;
          final heard = _current[i] == true;
          return Container(
            width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: answered ? (heard ? HearTechColors.green : HearTechColors.coralRed)
                  : HearTechColors.divider),
          );
        })),
        const SizedBox(height: 6),
        Text('$_answeredCount of 6 sounds completed', style: HearTechTextStyles.caption()),
        const SizedBox(height: 12),
        if (_allAnswered)
          HearTechButton(
            label: _round == 1 ? 'Complete Round 1' : 'Submit Results',
            onPressed: _round == 1 ? _completeRound1 : _submit),
      ])),
    ]);
  }

  Widget _buildSoundCard(int i) {
    final s = _sounds[i];
    final answered = _current[i] != null;
    final heard = _current[i] == true;
    final borderColor = !answered ? Colors.transparent
        : heard ? HearTechColors.green : HearTechColors.coralRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HearTechColors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: HearTechDecorations.subtleShadow,
        border: Border(left: BorderSide(color: borderColor, width: answered ? 4 : 0)),
      ),
      child: Row(children: [
        // Sound symbol
        Column(children: [
          Text(s['display']!, style: HearTechTextStyles.screenTitle().copyWith(fontSize: 32)),
          Text(s['freq']!, style: HearTechTextStyles.caption()),
        ]),
        const SizedBox(width: 12),

        // Play button
        IconButton(
          onPressed: _isPlayingSound ? null : () => _playSound(i),
          icon: Icon(_isPlayingSound ? Icons.volume_up : Icons.play_circle_fill,
            color: HearTechColors.deepTeal, size: 32),
        ),
        const Spacer(),

        // Response buttons
        _responseBtn('Heard It', Icons.hearing, HearTechColors.green,
          heard == true && answered, () => _respond(i, true)),
        const SizedBox(width: 8),
        _responseBtn('No', Icons.volume_off, HearTechColors.textSecondary,
          heard == false && answered, () => _respond(i, false)),
      ]),
    ).animate(delay: (i * 60).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05);
  }

  Widget _responseBtn(String label, IconData icon, Color color, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : HearTechColors.divider)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : HearTechColors.textSecondary),
          const SizedBox(width: 4),
          Text(label, style: HearTechTextStyles.caption(
            color: selected ? color : HearTechColors.textSecondary)
              .copyWith(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    );
  }

  // ── Round Break ────────────────────────────────────────────────────────
  Widget _buildRoundBreak() {
    final r1Heard = _round1.values.where((v) => v == true).length;
    return Padding(padding: const EdgeInsets.all(32), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: HearTechColors.deepTeal.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 64, color: HearTechColors.deepTeal),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text('Round 1 Complete!', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('$r1Heard/6 sounds heard at 1 metre',
          style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HearTechColors.purple.withValues(alpha: 0.08),
            borderRadius: HearTechDecorations.cardBorderRadius,
            border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.2))),
          child: Column(children: [
            const Icon(Icons.straighten, color: HearTechColors.purple, size: 28),
            const SizedBox(height: 8),
            Text('Move to 3 metres away', style: HearTechTextStyles.subtitle(color: HearTechColors.purple)),
            const SizedBox(height: 4),
            Text('Repeat the same 6 sounds from further away.',
              style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
          ]),
        ),
        const SizedBox(height: 40),
        HearTechButton(label: 'Start Round 2', onPressed: _startRound2),
      ],
    ));
  }

  // ── Result ─────────────────────────────────────────────────────────────
  Widget _buildResult() {
    if (_apiResult == null) return const SizedBox();
    final overall = _apiResult!['overallResult'] as String? ?? 'Error';
    final freq = _apiResult!['frequencyRangeEstimate'] as String? ?? '';
    final explanation = _apiResult!['clinicalExplanation'] as String? ?? '';
    final recommendation = _apiResult!['recommendation'] as String? ?? '';
    final flagged = List<Map<String, dynamic>>.from(
      (_apiResult!['flaggedSounds'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? []);

    Color badgeColor; IconData badgeIcon;
    if (overall == 'Pass') { badgeColor = HearTechColors.green; badgeIcon = Icons.check_circle; }
    else if (overall == 'Watch') { badgeColor = HearTechColors.warmOrange; badgeIcon = Icons.visibility; }
    else { badgeColor = HearTechColors.coralRed; badgeIcon = Icons.warning; }

    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      // Badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor, width: 2)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(badgeIcon, color: badgeColor, size: 28),
          const SizedBox(width: 10),
          Text(overall.toUpperCase(), style: HearTechTextStyles.screenTitle(color: badgeColor)),
        ]),
      ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
      const SizedBox(height: 24),

      // Bar Chart
      Container(
        height: 220, width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: HearTechColors.white,
          borderRadius: HearTechDecorations.cardBorderRadius, boxShadow: HearTechDecorations.subtleShadow),
        child: BarChart(BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.2, minY: 0,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(_sounds[v.toInt()]['sound']!, style: HearTechTextStyles.caption()
                    .copyWith(fontWeight: FontWeight.w600))))),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(6, (i) => BarChartGroupData(x: i, barRods: [
            BarChartRodData(toY: (_round1[i] == true) ? 1 : 0.05, color: HearTechColors.deepTeal, width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            BarChartRodData(toY: (_round2[i] == true) ? 1 : 0.05, color: HearTechColors.purple, width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
          ])),
        )),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _legendDot(HearTechColors.deepTeal, 'Round 1 (1m)'),
        const SizedBox(width: 16),
        _legendDot(HearTechColors.purple, 'Round 2 (3m)'),
      ]),
      const SizedBox(height: 20),

      // Frequency estimate
      if (freq.isNotEmpty) Container(
        width: double.infinity, padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: HearTechColors.paleTeal, borderRadius: BorderRadius.circular(12)),
        child: Text('Likely frequency range: $freq', style: HearTechTextStyles.body(color: HearTechColors.deepTeal)),
      ),

      // Flagged sounds
      if (flagged.isNotEmpty) ...[
        const SizedBox(height: 16),
        ...flagged.map((f) => Padding(padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: HearTechColors.coralRed, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('/${f['sound']}/ — ${f['frequency'] ?? ''} (${f['description'] ?? ''})',
              style: HearTechTextStyles.body())),
          ]))),
      ],

      // Explanation & Recommendation
      if (explanation.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(explanation, style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
      ],
      if (recommendation.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
          child: Text(recommendation, style: HearTechTextStyles.body(color: badgeColor)),
        ),
      ],

      const SizedBox(height: 24),
      HearTechButton(label: 'Retake Test', isSecondary: true, onPressed: () {
        setState(() { _phase = 0; _round = 1; _round1.clear(); _round2.clear(); _apiResult = null; });
      }),
      const SizedBox(height: 10),
      HearTechButton(label: _isSaving ? 'Saving...' : 'Save Result', onPressed: _isSaving ? null : _saveResult),
      const SizedBox(height: 16),
    ]));
  }

  Widget _legendDot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: HearTechTextStyles.caption()),
  ]);
}
