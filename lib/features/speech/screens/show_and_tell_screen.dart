import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

/// Show & Tell speech game — 5 category word bank, pulsing recording ring,
/// phonemes missed, clarity rating per word. Simulated speech analysis.
class ShowAndTellScreen extends ConsumerStatefulWidget {
  final String childId;
  const ShowAndTellScreen({super.key, required this.childId});

  @override
  ConsumerState<ShowAndTellScreen> createState() => _ShowAndTellScreenState();
}

class _ShowAndTellScreenState extends ConsumerState<ShowAndTellScreen>
    with SingleTickerProviderStateMixin {
  int _phase = 0; // 0=intro, 1=category, 2=word, 3=recording, 4=wordResult, 5=done

  // ── Category word bank ────────────────────────────────────────────────
  static const Map<String, List<Map<String, dynamic>>> _categories = {
    'Animals': [
      {'word': 'Cat', 'icon': '🐱', 'phonemes': ['k', 'æ', 't']},
      {'word': 'Dog', 'icon': '🐶', 'phonemes': ['d', 'ɒ', 'ɡ']},
      {'word': 'Fish', 'icon': '🐟', 'phonemes': ['f', 'ɪ', 'ʃ']},
      {'word': 'Bird', 'icon': '🐦', 'phonemes': ['b', 'ɜː', 'd']},
    ],
    'Food': [
      {'word': 'Milk', 'icon': '🥛', 'phonemes': ['m', 'ɪ', 'l', 'k']},
      {'word': 'Rice', 'icon': '🍚', 'phonemes': ['r', 'aɪ', 's']},
      {'word': 'Egg', 'icon': '🥚', 'phonemes': ['ɛ', 'ɡ']},
      {'word': 'Cake', 'icon': '🎂', 'phonemes': ['k', 'eɪ', 'k']},
    ],
    'Objects': [
      {'word': 'Ball', 'icon': '⚽', 'phonemes': ['b', 'ɔː', 'l']},
      {'word': 'Cup', 'icon': '🥤', 'phonemes': ['k', 'ʌ', 'p']},
      {'word': 'Shoe', 'icon': '👟', 'phonemes': ['ʃ', 'uː']},
      {'word': 'Book', 'icon': '📚', 'phonemes': ['b', 'ʊ', 'k']},
    ],
    'Body': [
      {'word': 'Hand', 'icon': '✋', 'phonemes': ['h', 'æ', 'n', 'd']},
      {'word': 'Eye', 'icon': '👁️', 'phonemes': ['aɪ']},
      {'word': 'Nose', 'icon': '👃', 'phonemes': ['n', 'əʊ', 'z']},
      {'word': 'Ear', 'icon': '👂', 'phonemes': ['ɪə']},
    ],
    'Transport': [
      {'word': 'Car', 'icon': '🚗', 'phonemes': ['k', 'ɑː']},
      {'word': 'Bus', 'icon': '🚌', 'phonemes': ['b', 'ʌ', 's']},
      {'word': 'Boat', 'icon': '⛵', 'phonemes': ['b', 'əʊ', 't']},
      {'word': 'Bike', 'icon': '🚲', 'phonemes': ['b', 'aɪ', 'k']},
    ],
  };

  String _selectedCategory = 'Animals';
  late List<Map<String, dynamic>> _words;
  int _currentWordIndex = 0;
  bool _isLoading = false;
  bool _isRecording = false;

  // Per-word results
  final List<Map<String, dynamic>> _wordResults = [];
  String? _currentClarity;
  int? _currentMatchScore;
  List<String> _currentPhonemesMissed = [];

  void _startGame() {
    _words = _categories[_selectedCategory]!;
    _currentWordIndex = 0;
    _wordResults.clear();
    setState(() => _phase = 2);
  }

  Future<void> _startRecording() async {
    setState(() { _phase = 3; _isRecording = true; });

    // Simulate 3-second recording + API analysis
    await Future.delayed(const Duration(seconds: 3));

    // Simulated results — in production: mic → WAV → FastAPI → Whisper → analysis
    final word = _words[_currentWordIndex];
    final phonemes = word['phonemes'] as List<String>;
    final missed = <String>[];

    // Simulate random phoneme misses
    for (int i = 0; i < phonemes.length; i++) {
      if ((_currentWordIndex + i) % 5 == 0) missed.add(phonemes[i]);
    }

    final matched = phonemes.length - missed.length;
    final matchPct = (matched / phonemes.length * 100).round();
    String clarity;
    if (matchPct >= 90) {
      clarity = 'Excellent';
    } else if (matchPct >= 70) {
      clarity = 'Good';
    } else if (matchPct >= 50) {
      clarity = 'Needs Practice';
    } else {
      clarity = 'Unclear';
    }

    setState(() {
      _isRecording = false;
      _phase = 4;
      _currentClarity = clarity;
      _currentMatchScore = matchPct;
      _currentPhonemesMissed = missed;
    });
  }

  void _nextWord() {
    _wordResults.add({
      'word': _words[_currentWordIndex]['word'],
      'clarity': _currentClarity,
      'matchScore': _currentMatchScore,
      'phonemesMissed': List<String>.from(_currentPhonemesMissed),
    });

    if (_currentWordIndex < _words.length - 1) {
      setState(() { _currentWordIndex++; _phase = 2; });
    } else {
      _submitResults();
    }
  }

  Future<void> _submitResults() async {
    setState(() { _phase = 5; _isLoading = true; });
    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final logId = fs.generateId('speechLogs');
      final avgScore = _wordResults.isEmpty ? 0
          : (_wordResults.map((r) => r['matchScore'] as int).reduce((a, b) => a + b) / _wordResults.length).round();

      final allMissed = <String>[];
      for (final r in _wordResults) {
        allMissed.addAll(r['phonemesMissed'] as List<String>);
      }

      final log = SpeechLogModel(
        logId: logId, game: 'showAndTell', conductedBy: uid, conductorRole: 'parent',
        date: DateTime.now(), score: avgScore,
        expectedWord: _words.map((w) => w['word'] as String).join(', '),
        matchScore: avgScore,
        clarityRating: avgScore >= 80 ? 'Good' : avgScore >= 50 ? 'Needs Practice' : 'Unclear',
        phonemesMissed: allMissed.toSet().toList(),
        aiAnalysisSummary: 'Tested ${_words.length} words in $_selectedCategory category. Average match: $avgScore%.',
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
        title: Text('Show & Tell', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _phase == 0 ? _buildIntro()
            : _phase == 1 ? _buildCategoryPicker()
            : _phase == 2 ? _buildWordDisplay()
            : _phase == 3 ? _buildRecording()
            : _phase == 4 ? _buildWordResult()
            : _buildDone(),
      ),
    );
  }

  // ── Phase 0: Intro ────────────────────────────────────────────────────
  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.deepTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.record_voice_over, size: 64, color: HearTechColors.deepTeal),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          Text('Show & Tell', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 12),
          Text(
            'A word and picture will appear. Whisper it to your child, then tap Record to capture their response.',
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HearTechColors.paleTeal,
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Row(children: [
              const Icon(Icons.tips_and_updates, color: HearTechColors.deepTeal, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Choose a word category, then go through 4 words. Results are saved automatically.',
                style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
              )),
            ]),
          ),
          const SizedBox(height: 40),
          HearTechButton(label: 'Choose Category', onPressed: () => setState(() => _phase = 1)),
        ],
      ),
    );
  }

  // ── Phase 1: Category Picker ──────────────────────────────────────────
  Widget _buildCategoryPicker() {
    final cats = _categories.keys.toList();
    final icons = ['🐾', '🍎', '📦', '🧍', '🚗'];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text('Pick a Category', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Choose words your child knows best.', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          ...List.generate(cats.length, (i) {
            final selected = _selectedCategory == cats[i];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cats[i]),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? HearTechColors.deepTeal.withValues(alpha: 0.1) : HearTechColors.white,
                  borderRadius: HearTechDecorations.cardBorderRadius,
                  border: Border.all(
                    color: selected ? HearTechColors.deepTeal : HearTechColors.deepTeal.withValues(alpha: 0.1),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(children: [
                  Text(icons[i], style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cats[i], style: HearTechTextStyles.subtitle(
                        color: selected ? HearTechColors.deepTeal : HearTechColors.textPrimary)),
                    Text('${_categories[cats[i]]!.length} words', style: HearTechTextStyles.caption()),
                  ])),
                  if (selected) const Icon(Icons.check_circle, color: HearTechColors.deepTeal),
                ]),
              ),
            ).animate(delay: (i * 60).ms).fadeIn(duration: 200.ms).slideX(begin: 0.1);
          }),
          const Spacer(),
          HearTechButton(label: 'Start with $_selectedCategory', onPressed: _startGame),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Phase 2: Word Display ─────────────────────────────────────────────
  Widget _buildWordDisplay() {
    final word = _words[_currentWordIndex];
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Word ${_currentWordIndex + 1} of ${_words.length}', style: HearTechTextStyles.caption()),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentWordIndex + 1) / _words.length,
            color: HearTechColors.deepTeal, backgroundColor: HearTechColors.paleTeal,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 40),
          Text('Whisper this word:', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 16),
          // Emoji illustration
          Text(word['icon'] as String, style: const TextStyle(fontSize: 80))
              .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            decoration: BoxDecoration(
              color: HearTechColors.deepTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.2)),
            ),
            child: Text(
              word['word'] as String,
              style: HearTechTextStyles.screenTitle(color: HearTechColors.deepTeal).copyWith(fontSize: 36, letterSpacing: 4),
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 40),
          HearTechButton(label: '🎤 Record Response', onPressed: _startRecording),
        ],
      ),
    );
  }

  // ── Phase 3: Recording — pulsing red ring ─────────────────────────────
  Widget _buildRecording() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing red ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.3), width: 3),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.3, 1.3), duration: 1000.ms)
                  .fadeOut(begin: 1, end: 0.3),
              // Middle pulsing ring
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.5), width: 2),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true), delay: 200.ms)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms),
              // Center mic icon
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: HearTechColors.coralRed,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: HearTechColors.coralRed.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 4)],
                ),
                child: const Icon(Icons.mic, size: 48, color: HearTechColors.white),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Listening...', style: HearTechTextStyles.screenTitle(color: HearTechColors.coralRed))
              .animate(onPlay: (c) => c.repeat(reverse: true)).fadeOut(begin: 1, end: 0.5, duration: 800.ms),
          const SizedBox(height: 8),
          Text('Say the word clearly', style: HearTechTextStyles.caption()),
        ],
      ),
    );
  }

  // ── Phase 4: Word Result — with phonemes missed ───────────────────────
  Widget _buildWordResult() {
    final color = _currentClarity == 'Excellent' ? HearTechColors.green
        : _currentClarity == 'Good' ? HearTechColors.deepTeal
        : _currentClarity == 'Needs Practice' ? HearTechColors.warmOrange
        : HearTechColors.coralRed;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(
              _currentClarity == 'Excellent' ? Icons.star
                  : _currentClarity == 'Good' ? Icons.thumb_up
                  : Icons.sentiment_neutral,
              size: 56, color: color,
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text(_currentClarity ?? 'Good', style: HearTechTextStyles.screenTitle(color: color)),
          const SizedBox(height: 8),
          Text('Match: ${_currentMatchScore ?? 0}%', style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 8),
          Text('Word: "${_words[_currentWordIndex]['word']}"', style: HearTechTextStyles.caption()),

          // Phonemes missed display
          if (_currentPhonemesMissed.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HearTechColors.warmOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Phonemes to practice:', style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)
                    .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: _currentPhonemesMissed.map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: HearTechColors.warmOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('/$p/', style: HearTechTextStyles.subtitle(color: HearTechColors.warmOrange)),
                  )).toList(),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          HearTechButton(
            label: _currentWordIndex < _words.length - 1 ? 'Next Word →' : 'See Results',
            onPressed: _nextWord,
          ),
        ],
      ),
    );
  }

  // ── Phase 5: Done ─────────────────────────────────────────────────────
  Widget _buildDone() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }

    final avgScore = _wordResults.isEmpty ? 0
        : (_wordResults.map((r) => r['matchScore'] as int).reduce((a, b) => a + b) / _wordResults.length).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.celebration, size: 64, color: HearTechColors.green),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text('Great Job! 🎉', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Average Score: $avgScore%', style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal)),
          const SizedBox(height: 24),
          // Word-by-word summary
          ...List.generate(_wordResults.length, (i) {
            final r = _wordResults[i];
            final clr = r['clarity'] == 'Excellent' ? HearTechColors.green
                : r['clarity'] == 'Good' ? HearTechColors.deepTeal
                : HearTechColors.warmOrange;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: clr.withValues(alpha: 0.06),
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: clr.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Text(_words[i]['icon'] as String, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r['word'] as String, style: HearTechTextStyles.subtitle()),
                  Text('${r['clarity']} • ${r['matchScore']}%', style: HearTechTextStyles.caption(color: clr)),
                ])),
                Icon(
                  r['clarity'] == 'Excellent' ? Icons.star : Icons.check_circle_outline,
                  color: clr,
                ),
              ]),
            );
          }),
          const SizedBox(height: 24),
          HearTechButton(label: 'Back to Dashboard', onPressed: () => context.go(Routes.parentDashboard)),
        ],
      ),
    );
  }
}
