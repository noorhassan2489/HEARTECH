import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

/// Ling Six Test — 2 rounds: 1 meter + 3 meters.
/// Tests 6 speech sounds spanning low → high frequency.
/// Result: Pass / Watch / Refer badge with frequency breakdown.
class LingSixScreen extends ConsumerStatefulWidget {
  final String childId;
  const LingSixScreen({super.key, required this.childId});

  @override
  ConsumerState<LingSixScreen> createState() => _LingSixScreenState();
}

class _LingSixScreenState extends ConsumerState<LingSixScreen> {
  int _phase = 0; // 0=intro, 1=testing, 2=roundBreak, 3=result
  int _round = 1;  // 1 = 1 meter, 2 = 3 meters
  int _currentSoundIndex = 0;
  bool _isLoading = false;
  bool _isPlayingSound = false;

  final List<Map<String, String>> _sounds = [
    {'sound': 'm', 'display': '/m/', 'example': 'as in "mama"', 'frequency': 'Low (250 Hz)'},
    {'sound': 'ah', 'display': '/ah/', 'example': 'as in "father"', 'frequency': 'Low-Mid (500 Hz)'},
    {'sound': 'oo', 'display': '/oo/', 'example': 'as in "food"', 'frequency': 'Mid (1000 Hz)'},
    {'sound': 'ee', 'display': '/ee/', 'example': 'as in "see"', 'frequency': 'Mid-High (2000 Hz)'},
    {'sound': 'sh', 'display': '/sh/', 'example': 'as in "shoe"', 'frequency': 'High (3000 Hz)'},
    {'sound': 's', 'display': '/s/', 'example': 'as in "sun"', 'frequency': 'Very High (4000+ Hz)'},
  ];

  // Results for both rounds
  final List<LingSixResult> _round1Results = [];
  final List<LingSixResult> _round2Results = [];

  List<LingSixResult> get _currentResults => _round == 1 ? _round1Results : _round2Results;

  String get _distanceLabel => _round == 1 ? '1 meter' : '3 meters';

  Future<void> _playSound() async {
    setState(() => _isPlayingSound = true);
    // Simulate playing the sound (in production: just_audio)
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() => _isPlayingSound = false);
  }

  void _recordResult(bool heard) {
    _currentResults.add(LingSixResult(
      sound: _sounds[_currentSoundIndex]['sound']!,
      heard: heard,
    ));

    if (_currentSoundIndex < _sounds.length - 1) {
      setState(() => _currentSoundIndex++);
    } else if (_round == 1) {
      // Finished round 1 → break screen
      setState(() => _phase = 2);
    } else {
      // Finished round 2 → save & show results
      _saveResults();
    }
  }

  void _startRound2() {
    setState(() {
      _round = 2;
      _currentSoundIndex = 0;
      _phase = 1;
    });
  }

  Future<void> _saveResults() async {
    setState(() { _phase = 3; _isLoading = true; });

    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final logId = fs.generateId('speechLogs');

      final allResults = [..._round1Results, ..._round2Results];
      final heardCount = allResults.where((r) => r.heard).length;
      final score = (heardCount / allResults.length * 100).round();

      // Frequency flag detection
      String? frequencyFlag;
      final missedSounds = allResults.where((r) => !r.heard).toList();
      if (missedSounds.isNotEmpty) {
        final missedIndices = missedSounds.map((r) =>
            _sounds.indexWhere((s) => s['sound'] == r.sound)).toSet().toList();
        if (missedIndices.every((i) => i >= 4)) {
          frequencyFlag = 'high_frequency_loss';
        } else if (missedIndices.every((i) => i <= 1)) {
          frequencyFlag = 'low_frequency_loss';
        } else {
          frequencyFlag = 'mixed_frequency_concern';
        }
      }

      final log = SpeechLogModel(
        logId: logId, game: 'lingSix', conductedBy: uid, conductorRole: 'parent',
        date: DateTime.now(), score: score,
        lingResults: allResults, frequencyFlag: frequencyFlag,
      );

      await fs.addSpeechLog(widget.childId, log);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text('Ling Six Test', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
        actions: [
          if (_phase == 1)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HearTechColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text('Round $_round • $_distanceLabel',
                  style: HearTechTextStyles.caption(color: HearTechColors.purple).copyWith(fontWeight: FontWeight.w700))),
            ),
        ],
      ),
      body: SafeArea(
        child: _phase == 0 ? _buildIntro()
            : _phase == 1 ? _buildTest()
            : _phase == 2 ? _buildRoundBreak()
            : _buildResult(),
      ),
    );
  }

  // ── Intro ─────────────────────────────────────────────────────────────
  Widget _buildIntro() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hearing, size: 64, color: HearTechColors.purple),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          Text('Ling Six Test', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 12),
          Text(
            'This test checks if your child can hear 6 key speech sounds across different frequencies.',
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Two rounds info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HearTechColors.paleTeal,
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: HearTechColors.deepTeal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.straighten, size: 16, color: HearTechColors.deepTeal),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Round 1: 1 meter away', style: HearTechTextStyles.body())),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: HearTechColors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.straighten, size: 16, color: HearTechColors.purple),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text('Round 2: 3 meters away', style: HearTechTextStyles.body())),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HearTechColors.warmOrange.withValues(alpha: 0.08),
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: HearTechColors.warmOrange, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Make sure the room is quiet. Say each sound without showing your lips.',
                style: HearTechTextStyles.caption(color: HearTechColors.warmOrange),
              )),
            ]),
          ),
          const SizedBox(height: 32),
          HearTechButton(label: 'Begin Test', onPressed: () => setState(() => _phase = 1)),
        ],
      ),
    );
  }

  // ── Testing Phase ─────────────────────────────────────────────────────
  Widget _buildTest() {
    final sound = _sounds[_currentSoundIndex];
    final freqIndex = _currentSoundIndex; // 0=low → 5=very high
    final freqColor = Color.lerp(HearTechColors.deepTeal, HearTechColors.purple, freqIndex / 5)!;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final done = i < _currentSoundIndex;
              final current = i == _currentSoundIndex;
              Color dotColor;
              if (done) {
                final result = _currentResults[i];
                dotColor = result.heard ? HearTechColors.green : HearTechColors.coralRed;
              } else if (current) {
                dotColor = freqColor;
              } else {
                dotColor = HearTechColors.paleTeal;
              }
              return Container(
                width: current ? 16 : 12,
                height: current ? 16 : 12,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: current ? Border.all(color: freqColor, width: 2) : null,
                ),
                child: done ? Icon(
                  _currentResults[i].heard ? Icons.check : Icons.close,
                  size: 8, color: HearTechColors.white,
                ) : null,
              );
            }),
          ),
          const SizedBox(height: 12),
          Text('Sound ${_currentSoundIndex + 1} of 6', style: HearTechTextStyles.caption()),

          const Spacer(),

          // Sound display
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: freqColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Text(
              sound['display']!,
              style: HearTechTextStyles.screenTitle(color: freqColor).copyWith(fontSize: 48),
            ),
          ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8)),
          const SizedBox(height: 16),
          Text(sound['example']!, style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: freqColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(sound['frequency']!, style: HearTechTextStyles.caption(color: freqColor)),
          ),
          const SizedBox(height: 16),

          // Play sound button
          OutlinedButton.icon(
            onPressed: _isPlayingSound ? null : _playSound,
            icon: Icon(_isPlayingSound ? Icons.volume_up : Icons.play_circle_outline, color: freqColor),
            label: Text(_isPlayingSound ? 'Playing...' : 'Play Sound',
                style: TextStyle(color: freqColor)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: freqColor),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const Spacer(),

          // Response buttons
          Text('Did the child hear it?', style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _recordResult(true),
                  icon: const Icon(Icons.check, color: HearTechColors.white),
                  label: const Text('Yes', style: TextStyle(color: HearTechColors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HearTechColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _recordResult(false),
                  icon: const Icon(Icons.close, color: HearTechColors.white),
                  label: const Text('No', style: TextStyle(color: HearTechColors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HearTechColors.coralRed,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Round Break ───────────────────────────────────────────────────────
  Widget _buildRoundBreak() {
    final r1Heard = _round1Results.where((r) => r.heard).length;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HearTechColors.deepTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 64, color: HearTechColors.deepTeal),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Round 1 Complete!', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('$r1Heard/6 sounds heard at 1 meter', style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HearTechColors.purple.withValues(alpha: 0.08),
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              const Icon(Icons.straighten, color: HearTechColors.purple, size: 28),
              const SizedBox(height: 8),
              Text('Move to 3 meters away', style: HearTechTextStyles.subtitle(color: HearTechColors.purple)),
              const SizedBox(height: 4),
              Text('Repeat the same 6 sounds from further away.',
                  style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 40),
          HearTechButton(label: 'Start Round 2', onPressed: _startRound2),
        ],
      ),
    );
  }

  // ── Results ───────────────────────────────────────────────────────────
  Widget _buildResult() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }

    final r1Heard = _round1Results.where((r) => r.heard).length;
    final r2Heard = _round2Results.where((r) => r.heard).length;
    final totalHeard = r1Heard + r2Heard;
    final totalScore = (totalHeard / 12 * 100).round();

    // Determine Pass/Watch/Refer
    String badge;
    Color badgeColor;
    IconData badgeIcon;
    if (totalScore >= 90) {
      badge = 'PASS'; badgeColor = HearTechColors.green; badgeIcon = Icons.check_circle;
    } else if (totalScore >= 60) {
      badge = 'WATCH'; badgeColor = HearTechColors.warmOrange; badgeIcon = Icons.visibility;
    } else {
      badge = 'REFER'; badgeColor = HearTechColors.coralRed; badgeIcon = Icons.warning;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text('Test Complete', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 16),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor, width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(badgeIcon, color: badgeColor, size: 28),
              const SizedBox(width: 10),
              Text(badge, style: HearTechTextStyles.screenTitle(color: badgeColor)),
            ]),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),

          // Round comparison
          Row(children: [
            Expanded(child: _roundCard('Round 1', '1 meter', r1Heard, HearTechColors.deepTeal)),
            const SizedBox(width: 12),
            Expanded(child: _roundCard('Round 2', '3 meters', r2Heard, HearTechColors.purple)),
          ]),
          const SizedBox(height: 20),

          // Sound-by-sound grid
          Text('Sound Details', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),
          ...List.generate(6, (i) {
            final sound = _sounds[i];
            final r1 = i < _round1Results.length ? _round1Results[i].heard : false;
            final r2 = i < _round2Results.length ? _round2Results[i].heard : false;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: HearTechColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.1)),
              ),
              child: Row(children: [
                SizedBox(width: 40, child: Text(sound['display']!, style: HearTechTextStyles.subtitle())),
                Expanded(child: Text(sound['frequency']!, style: HearTechTextStyles.caption())),
                // Round 1 result
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: r1 ? HearTechColors.green.withValues(alpha: 0.1) : HearTechColors.coralRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(r1 ? Icons.check : Icons.close, size: 16,
                      color: r1 ? HearTechColors.green : HearTechColors.coralRed),
                ),
                const SizedBox(width: 8),
                // Round 2 result
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: r2 ? HearTechColors.green.withValues(alpha: 0.1) : HearTechColors.coralRed.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(r2 ? Icons.check : Icons.close, size: 16,
                      color: r2 ? HearTechColors.green : HearTechColors.coralRed),
                ),
              ]),
            );
          }),

          // Legend
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legendDot(HearTechColors.deepTeal, '1m'),
            const SizedBox(width: 16),
            _legendDot(HearTechColors.purple, '3m'),
          ]),

          const SizedBox(height: 24),
          HearTechButton(label: 'Back to Dashboard', onPressed: () => context.go(Routes.parentDashboard)),
        ],
      ),
    );
  }

  Widget _roundCard(String title, String distance, int heard, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: HearTechDecorations.cardBorderRadius,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Text(title, style: HearTechTextStyles.subtitle(color: color)),
        Text(distance, style: HearTechTextStyles.caption()),
        const SizedBox(height: 8),
        Text('$heard/6', style: HearTechTextStyles.screenTitle(color: color).copyWith(fontSize: 28)),
        Text('heard', style: HearTechTextStyles.caption()),
      ]),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: HearTechTextStyles.caption()),
    ]);
  }
}
