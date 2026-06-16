import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/navigation_utils.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/features/speech/utils/speech_session_notifications.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

class _LingSoundMeta {
  const _LingSoundMeta({
    required this.sound,
    required this.display,
    required this.freq,
    required this.label,
  });

  final String sound;
  final String display;
  final String freq;
  final String label;
}

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
  int? _currentPlayingIndex;
  bool _isSaving = false;
  bool _isLoadingAssets = true;
  String _assetsMessage = '';
  late final AudioPlayer _audioPlayer;

  static const _soundCount = 6;

  static const _defaultSounds = <_LingSoundMeta>[
    _LingSoundMeta(sound: 'm', display: '/m/', freq: '250-500 Hz', label: 'Low frequency'),
    _LingSoundMeta(sound: 'ah', display: '/ah/', freq: '500-1000 Hz', label: 'Low-mid'),
    _LingSoundMeta(sound: 'oo', display: '/oo/', freq: '500-1000 Hz', label: 'Mid'),
    _LingSoundMeta(sound: 'ee', display: '/ee/', freq: '1000-3000 Hz', label: 'Mid-high'),
    _LingSoundMeta(sound: 'sh', display: '/sh/', freq: '2000-4000 Hz', label: 'High'),
    _LingSoundMeta(sound: 's', display: '/s/', freq: '4000-8000 Hz', label: 'Very high'),
  ];

  List<_LingSoundMeta> _sounds = List<_LingSoundMeta>.from(_defaultSounds);
  final Map<String, String> _audioUrls = {};
  final Map<String, String> _imageUrls = {};
  final Map<String, IconData> _lingFallbackIcons = const {
    'm': Icons.multitrack_audio,
    'ah': Icons.music_note,
    'oo': Icons.surround_sound,
    'ee': Icons.graphic_eq,
    'sh': Icons.hearing,
    's': Icons.waves,
  };

  // null = not answered yet
  final Map<int, bool?> _round1 = {};
  final Map<int, bool?> _round2 = {};
  int _activeSoundIndex = 0;
  Map<int, bool?> get _current => _round == 1 ? _round1 : _round2;

  // API result
  Map<String, dynamic>? _apiResult;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAssets());
  }

  _LingSoundMeta _metaFor(int index) {
    if (index < 0 || index >= _soundCount) return _defaultSounds[0];
    if (index >= _sounds.length) return _defaultSounds[index];
    return _sounds[index];
  }

  Future<void> _loadAssets() async {
    _assetsMessage = '';
    _audioUrls.clear();
    _imageUrls.clear();
    _sounds = List<_LingSoundMeta>.from(_defaultSounds);

    try {
      final api = ref.read(fastApiServiceProvider);
      final data = await api.getLingSixAssets();
      _assetsMessage = data['message'] as String? ?? '';
      final soundsRaw = data['sounds'] as List?;
      if (soundsRaw != null) {
        for (final item in soundsRaw) {
          final sound = Map<String, dynamic>.from(item as Map);
          final key = (sound['sound'] as String? ?? '').toLowerCase().trim();
          if (key.isEmpty) continue;

          final audioUrl = sound['audioUrl'] as String?;
          if (audioUrl != null && audioUrl.isNotEmpty) {
            _audioUrls[key] = audioUrl;
          }
          final imageUrl = sound['imageUrl'] as String?;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            _imageUrls[key] = imageUrl;
          }

          final index = _defaultSounds.indexWhere((s) => s.sound == key);
          if (index >= 0) {
            final fallback = _defaultSounds[index];
            _sounds[index] = _LingSoundMeta(
              sound: key,
              display: (sound['display'] as String?)?.trim().isNotEmpty == true
                  ? (sound['display'] as String).trim()
                  : fallback.display,
              freq: (sound['frequency'] as String?)?.trim().isNotEmpty == true
                  ? (sound['frequency'] as String).trim()
                  : fallback.freq,
              label: (sound['label'] as String?)?.trim().isNotEmpty == true
                  ? (sound['label'] as String).trim()
                  : fallback.label,
            );
          }
        }
      }
    } catch (_) {
      _assetsMessage = 'Could not load Ling Six assets from server. Using local fallback.';
    }
    if (mounted) setState(() => _isLoadingAssets = false);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  int get _answeredCount => _current.values.where((v) => v != null).length;
  bool get _allAnswered => _answeredCount == _soundCount;

  Future<void> _playSound(int index) async {
    setState(() {
      _isPlayingSound = true;
      _currentPlayingIndex = index;
    });
    try {
      await _audioPlayer.stop();
      final name = _metaFor(index).sound;
      final remoteUrl = _audioUrls[name];
      if (remoteUrl != null &&
          (remoteUrl.startsWith('http://') || remoteUrl.startsWith('https://'))) {
        await _audioPlayer.setUrl(remoteUrl);
      } else {
        await _audioPlayer.setAsset('assets/sounds/ling_$name.mp3');
      }
      await _audioPlayer.play();
      await _audioPlayer.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed);
    } catch (_) {
      // Asset may not exist yet — simulate
      await Future.delayed(const Duration(milliseconds: 800));
    }
    if (mounted) {
      setState(() {
        _isPlayingSound = false;
        _currentPlayingIndex = null;
      });
    }
  }

  void _respond(int index, bool heard) {
    setState(() {
      _current[index] = heard;
      if (index < _soundCount - 1 && _activeSoundIndex == index) {
        _activeSoundIndex = index + 1;
      }
    });
  }

  void _completeRound1() {
    setState(() => _phase = 2);
  }

  void _startRound2() {
    setState(() {
      _round = 2;
      _phase = 1;
      _activeSoundIndex = 0;
    });
  }

  Future<void> _submit() async {
    setState(() => _phase = 3);
    try {
      final api = ref.read(fastApiServiceProvider);
      final results = List.generate(_soundCount, (i) => {
        'sound': _metaFor(i).sound,
        'round1heard': _round1[i] ?? false,
        'round2heard': _round2[i] ?? false,
      });
      _apiResult = await api.analyzeLingSix(results: results, childId: widget.childId);
    } catch (e) {
      _apiResult = {
        'overallResult': 'Error', 'frequencyRangeEstimate': '',
        'flaggedSounds': [], 'clinicalExplanation': 'Analysis failed: $e',
        'recommendation': 'Please try again.',
        'frequencyProfile': {
          'orderedMissedSounds': <String>[],
          'frequencyBands': <String>[],
          'rationale': '',
        },
        'roundSummary': {
          'round1HeardCount': 0,
          'round2HeardCount': 0,
          'totalSounds': 6,
        },
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

      final lingResults = List.generate(_soundCount, (i) => LingSixResult(
        sound: _metaFor(i).sound,
        round1heard: _round1[i] ?? false,
        round2heard: _round2[i] ?? false,
      ));

      final log = SpeechLogModel(
        logId: logId, game: 'lingSix', conductedBy: uid, conductorRole: role,
        date: DateTime.now(), score: score, lingResults: lingResults,
        frequencyFlag: (_apiResult?['overallResult'] as String?)?.toLowerCase(),
        aiAnalysisSummary: [
          _apiResult?['clinicalExplanation'] as String? ?? '',
          (_apiResult?['frequencyProfile']?['rationale'] as String?) ?? '',
        ].where((line) => line.trim().isNotEmpty).join(' | '),
      );
      await fs.addSpeechLog(widget.childId, log);

      try {
        final aggregate = await ref.read(fastApiServiceProvider).aggregateRiskScore(
          childId: widget.childId,
          trigger: 'speech_log',
        );
        await fs.updateChild(widget.childId, {
          'lastSpeechSessionDate': DateTime.now(),
          'riskScore': aggregate['riskScore'],
          'riskLevel': aggregate['riskLevel'],
          'lastUpdatedAt': DateTime.now(),
          if (aggregate['breakdown'] != null) 'riskBreakdown': aggregate['breakdown'],
        });
      } catch (_) {
        await fs.updateChild(widget.childId, {'lastSpeechSessionDate': DateTime.now()});
      }

      final child = await fs.getChild(widget.childId);
      if (child != null) {
        await notifySpeechSessionSaved(
          fastApi: ref.read(fastApiServiceProvider),
          child: child,
          conductorRole: role,
          gameName: 'Ling Six Test',
          score: score,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result saved! ✓'), backgroundColor: HearTechColors.green));
        closeSpeechScreen(context, role: role, fromGameScreen: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider) ?? 'parent';
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: HearTechColors.deepTeal,
        leading: IconButton(icon: const Icon(Icons.close, color: HearTechColors.white),
          onPressed: () =>
              closeSpeechScreen(context, role: role, fromGameScreen: true)),
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
    if (_isLoadingAssets) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }
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
        if (_assetsMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HearTechColors.warmOrange.withValues(alpha: 0.08),
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Text(
              _assetsMessage,
              style: HearTechTextStyles.caption(color: HearTechColors.warmOrange),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 32),
        HearTechButton(
          label: _isLoadingAssets ? 'Loading sounds...' : 'Begin Test',
          onPressed: _isLoadingAssets ? null : () => setState(() {
                _phase = 1;
                _activeSoundIndex = 0;
              }),
        ),
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

  // ── Testing — one sound at a time (avoids scroll/list layout bugs) ─────
  Widget _buildTesting() {
    final i = _activeSoundIndex;
    final meta = _metaFor(i);
    final imageUrl = _imageUrls[meta.sound];
    final answered = _current[i] != null;
    final heard = _current[i] == true;
    final isPlaying = _isPlayingSound && _currentPlayingIndex == i;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: HearTechColors.warmOrange.withValues(alpha: 0.15),
          child: Text(
            _round == 1
                ? 'Child should be 1 metre away from the device'
                : 'Move the child 3 metres away from the device',
            style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)
                .copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_soundCount, (idx) {
              final done = _current[idx] != null;
              final ok = _current[idx] == true;
              final active = idx == i;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: idx == 0 ? 0 : 4, right: idx == _soundCount - 1 ? 0 : 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _activeSoundIndex = idx),
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? HearTechColors.deepTeal
                            : done
                                ? (ok ? HearTechColors.green : HearTechColors.coralRed)
                                : HearTechColors.divider,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _metaFor(idx).sound,
                        style: TextStyle(
                          color: active || done ? HearTechColors.white : HearTechColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: answered
                      ? (heard ? HearTechColors.green : HearTechColors.coralRed)
                      : HearTechColors.divider,
                  width: answered ? 2 : 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sound ${i + 1} of $_soundCount',
                            style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
                          ),
                          const SizedBox(height: 20),
                          _buildActiveThumbnail(meta.sound, imageUrl),
                          const SizedBox(height: 20),
                          Text(
                            meta.display,
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2E35),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            meta.freq,
                            style: HearTechTextStyles.body(color: HearTechColors.deepTeal),
                          ),
                          Text(
                            meta.label,
                            style: HearTechTextStyles.caption(),
                          ),
                          const SizedBox(height: 28),
                          HearTechButton(
                            label: isPlaying ? 'Playing sound...' : 'Play sound',
                            icon: isPlaying ? Icons.volume_up : Icons.play_arrow_rounded,
                            onPressed: _isPlayingSound ? null : () => _playSound(i),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _respond(i, true),
                                  icon: const Icon(Icons.hearing, size: 18),
                                  label: const Text('Heard It'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: heard && answered
                                        ? HearTechColors.green
                                        : HearTechColors.deepTeal,
                                    foregroundColor: HearTechColors.white,
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _respond(i, false),
                                  icon: const Icon(Icons.volume_off, size: 18),
                                  label: const Text('No'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: !heard && answered
                                        ? HearTechColors.coralRed
                                        : HearTechColors.textSecondary,
                                    minimumSize: const Size(0, 48),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed:
                                    i > 0 ? () => setState(() => _activeSoundIndex--) : null,
                                child: const Text('← Previous'),
                              ),
                              TextButton(
                                onPressed: i < _soundCount - 1
                                    ? () => setState(() => _activeSoundIndex++)
                                    : null,
                                child: const Text('Next →'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Text(
                '$_answeredCount of $_soundCount sounds completed',
                style: HearTechTextStyles.caption(),
              ),
              const SizedBox(height: 12),
              if (_allAnswered)
                HearTechButton(
                  label: _round == 1 ? 'Complete Round 1' : 'Submit Results',
                  onPressed: _round == 1 ? _completeRound1 : _submit,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveThumbnail(String soundKey, String? imageUrl) {
    final hasRemote = imageUrl != null &&
        (imageUrl.startsWith('http://') || imageUrl.startsWith('https://'));

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 96,
        height: 96,
        color: HearTechColors.paleTeal,
        alignment: Alignment.center,
        child: hasRemote
            ? Image.network(
                imageUrl,
                width: 96,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) => Icon(
                  _lingFallbackIcons[soundKey] ?? Icons.hearing,
                  size: 44,
                  color: HearTechColors.deepTeal,
                ),
              )
            : Icon(
                _lingFallbackIcons[soundKey] ?? Icons.hearing,
                size: 44,
                color: HearTechColors.deepTeal,
              ),
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
    final profile = Map<String, dynamic>.from(
      (_apiResult!['frequencyProfile'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
    );
    final roundSummary = Map<String, dynamic>.from(
      (_apiResult!['roundSummary'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
    );
    final profileBands = List<String>.from(profile['frequencyBands'] ?? const <String>[]);
    final profileRationale = profile['rationale'] as String? ?? '';
    final flagged = List<Map<String, dynamic>>.from(
      (_apiResult!['flaggedSounds'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? []);

    Color badgeColor; IconData badgeIcon;
    final overallLower = overall.toLowerCase();
    if (overallLower == 'pass') { badgeColor = HearTechColors.green; badgeIcon = Icons.check_circle; }
    else if (overallLower == 'watch') { badgeColor = HearTechColors.warmOrange; badgeIcon = Icons.visibility; }
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
                child: Text(_metaFor(v.toInt()).sound, style: HearTechTextStyles.caption()
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
      if (roundSummary.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HearTechColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HearTechColors.divider),
          ),
          child: Text(
            'Round 1 heard: ${roundSummary['round1HeardCount'] ?? 0}/${roundSummary['totalSounds'] ?? 6}  •  '
            'Round 2 heard: ${roundSummary['round2HeardCount'] ?? 0}/${roundSummary['totalSounds'] ?? 6}',
            style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
          ),
        ),
      ],
      if (profileBands.isNotEmpty || profileRationale.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: HearTechColors.paleTeal.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profileBands.isNotEmpty)
                Text(
                  'Detected bands: ${profileBands.join(', ')}',
                  style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              if (profileRationale.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  profileRationale,
                  style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],

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
