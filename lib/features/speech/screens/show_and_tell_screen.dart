import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/navigation_utils.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/features/speech/utils/speech_session_notifications.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Show & Tell speech game — category chips, Cloudinary/emoji images,
/// real audio recording (.wav), FastAPI Whisper analysis, phoneme feedback.
class ShowAndTellScreen extends ConsumerStatefulWidget {
  final String childId;
  const ShowAndTellScreen({super.key, required this.childId});

  @override
  ConsumerState<ShowAndTellScreen> createState() => _ShowAndTellScreenState();
}

class _ShowAndTellScreenState extends ConsumerState<ShowAndTellScreen>
    with SingleTickerProviderStateMixin {

  bool get _analysisUnavailable {
    final result = _analysisResult;
    if (result == null) return true;
    if (result['isFallback'] == true ||
        result['analysisUnavailable'] == true ||
        result['analysisFallbackUsed'] == true) {
      return true;
    }
    final clarity = (result['clarityRating'] as String? ?? '').toLowerCase();
    return clarity == 'unavailable';
  }

  // ── State ──────────────────────────────────────────────────────────────
  String _selectedCategory = 'animals';
  Map<String, List<Map<String, dynamic>>> _imageBank = {};
  List<Map<String, dynamic>> _currentPool = [];
  int _currentIndex = 0;
  bool _isLoadingImages = true;
  String _imageLoadMessage = '';

  // Recording
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  bool _isAnalyzing = false;
  int _countdownValue = 0;
  int _elapsedSeconds = 0;
  Timer? _recordingTimer;
  Timer? _autoStopTimer;
  String? _recordedFilePath;

  // Result
  Map<String, dynamic>? _analysisResult;
  bool _showResult = false;
  bool _isSaving = false;

  static final _cloudinarySuffix = RegExp(r'_[a-z0-9]{6}$', caseSensitive: false);

  String _normalizeWord(String raw) {
    var word = raw.trim();
    word = word.replaceAll(_cloudinarySuffix, '');
    word = word.replaceAll('_', ' ').replaceAll('-', ' ').trim();
    return word;
  }

  static const _categories = ['animals', 'food', 'objects', 'body', 'transport'];
  static const _categoryLabels = {
    'animals': 'Animals', 'food': 'Food', 'objects': 'Objects',
    'body': 'Body Parts', 'transport': 'Transport',
  };

  // Emoji fallback for when URL starts with "emoji://"
  static const _emojiMap = {
    'cat': '🐱', 'dog': '🐶', 'fish': '🐟', 'bird': '🐦', 'cow': '🐄',
    'duck': '🦆', 'frog': '🐸', 'horse': '🐴', 'sheep': '🐑', 'lion': '🦁',
    'milk': '🥛', 'rice': '🍚', 'egg': '🥚', 'cake': '🎂', 'apple': '🍎',
    'banana': '🍌', 'bread': '🍞', 'cheese': '🧀', 'grape': '🍇', 'orange': '🍊',
    'ball': '⚽', 'cup': '🥤', 'shoe': '👟', 'book': '📚', 'chair': '🪑',
    'clock': '🕐', 'key': '🔑', 'phone': '📱', 'star': '⭐', 'hat': '🎩',
    'hand': '✋', 'eye': '👁️', 'nose': '👃', 'ear': '👂', 'mouth': '👄',
    'foot': '🦶', 'teeth': '🦷', 'hair': '💇', 'thumb': '👍', 'leg': '🦵',
    'car': '🚗', 'bus': '🚌', 'boat': '⛵', 'bike': '🚲', 'train': '🚂',
    'plane': '✈️', 'truck': '🚛', 'taxi': '🚕', 'ship': '🚢', 'rocket': '🚀',
  };

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _loadImages();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ── Image Loading (API first, local assets fallback) ───────────────────
  Future<void> _loadImages() async {
    _imageLoadMessage = '';
    final apiBank = await _loadShowAndTellFromApi();
    if (apiBank.isNotEmpty) {
      _imageBank = apiBank;
    } else {
      _imageBank = await _loadLocalShowAndTellAssets();
      if (_imageBank.isEmpty && _imageLoadMessage.isEmpty) {
        _imageLoadMessage =
            'No images available. Upload to Cloudinary under heartech/show_and_tell/{category}/ '
            'or add local files under assets/images/show_and_tell/.';
      }
    }

    _selectCategory(_selectedCategory);
    if (mounted) setState(() => _isLoadingImages = false);
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadShowAndTellFromApi() async {
    try {
      final api = ref.read(fastApiServiceProvider);
      final data = await api.getSpeechImages();
      _imageLoadMessage = data['message'] as String? ?? '';

      Map<String, dynamic> rawCategories;
      if (data['categories'] is Map) {
        rawCategories = Map<String, dynamic>.from(data['categories'] as Map);
      } else {
        rawCategories = data;
      }

      final bank = <String, List<Map<String, dynamic>>>{};
      for (final category in _categories) {
        final items = rawCategories[category];
        if (items is! List || items.isEmpty) continue;
        bank[category] = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((item) {
              final url = item['url']?.toString() ?? '';
              return url.startsWith('http://') ||
                  url.startsWith('https://') ||
                  url.startsWith('emoji://');
            })
            .map((item) {
              final rawWord = item['word']?.toString() ?? '';
              return {
                ...item,
                'word': _normalizeWord(rawWord),
              };
            })
            .toList();
      }
      bank.removeWhere((_, value) => value.isEmpty);
      return bank;
    } catch (_) {
      _imageLoadMessage = 'Could not load images from server. Using local fallback if available.';
      return {};
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadLocalShowAndTellAssets() async {
    try {
      final manifestRaw = await rootBundle.loadString('AssetManifest.json');
      final manifest = Map<String, dynamic>.from(json.decode(manifestRaw));
      final bank = <String, List<Map<String, dynamic>>>{};
      for (final category in _categories) {
        bank[category] = [];
      }

      for (final key in manifest.keys) {
        final lowerKey = key.toLowerCase();
        final isShowAndTellPath = lowerKey.contains('/show_and_tell/') ||
            lowerKey.contains('/show-and-tell/') ||
            lowerKey.contains('/showandtell/');
        if (!isShowAndTellPath) continue;
        final lower = key.toLowerCase();
        final isImage = lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.webp');
        if (!isImage) continue;

        final parts = key.split('/');
        if (parts.length < 2) continue;
        final lowerParts = parts.map((part) => part.toLowerCase()).toList();
        var category = '';
        final markerIndex = lowerParts.indexWhere((part) =>
            part == 'show_and_tell' || part == 'show-and-tell' || part == 'showandtell');
        if (markerIndex >= 0 && markerIndex + 1 < lowerParts.length) {
          final candidate = lowerParts[markerIndex + 1];
          if (bank.containsKey(candidate)) {
            category = candidate;
          }
        }
        if (category.isEmpty) {
          for (final candidate in _categories) {
            if (lowerParts.contains(candidate)) {
              category = candidate;
              break;
            }
          }
        }
        if (category.isEmpty) continue;

        final fileName = parts.last;
        final dot = fileName.lastIndexOf('.');
        final rawWord = dot > 0 ? fileName.substring(0, dot) : fileName;
        final normalizedWord = _normalizeWord(rawWord);

        bank[category]!.add({
          'word': normalizedWord,
          'url': 'asset://$key',
        });
      }

      bank.removeWhere((_, value) => value.isEmpty);
      return bank;
    } catch (_) {
      return {};
    }
  }

  void _selectCategory(String cat) {
    _selectedCategory = cat;
    _currentPool = List.from(_imageBank[cat] ?? []);
    _currentPool.shuffle(Random());
    _currentIndex = 0;
    _resetResult();
    setState(() {});
  }

  void _nextWord() {
    if (_currentPool.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % _currentPool.length;
      _resetResult();
    });
  }

  void _resetResult() {
    _analysisResult = null;
    _showResult = false;
    _isRecording = false;
    _isAnalyzing = false;
    _elapsedSeconds = 0;
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
  }

  String get _currentWord =>
      _currentPool.isNotEmpty ? _currentPool[_currentIndex]['word'] ?? '' : '';
  String get _currentUrl =>
      _currentPool.isNotEmpty ? _currentPool[_currentIndex]['url'] ?? '' : '';
  bool get _isEmoji => _currentUrl.startsWith('emoji://');
  bool get _isAssetImage => _currentUrl.startsWith('asset://');
  String get _assetPath => _isAssetImage ? _currentUrl.replaceFirst('asset://', '') : '';

  // ── Recording ──────────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_countdownValue > 0 || _isAnalyzing) return;
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _runCountdownThenStartRecording();
    }
  }

  Future<void> _runCountdownThenStartRecording() async {
    for (var i = 3; i >= 1; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (!mounted) return;
    setState(() => _countdownValue = 0);
    await _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Microphone Required'),
            content: const Text(
              'HearTech needs microphone access to record your child\'s speech. '
              'Open Settings → HearTech → Microphone and allow access, then return and try again.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/show_tell_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: path,
      );

      setState(() { _isRecording = true; _elapsedSeconds = 0; });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _elapsedSeconds = t.tick);
      });

      _autoStopTimer = Timer(const Duration(seconds: 5), () {
        if (_isRecording) _stopRecording();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recorder failed to start: $e'),
          backgroundColor: HearTechColors.coralRed,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _autoStopTimer?.cancel();
    _recordedFilePath = await _audioRecorder.stop();
    if (_recordedFilePath == null || _recordedFilePath!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio captured. Please try again.'),
          backgroundColor: HearTechColors.coralRed,
        ),
      );
      return;
    }
    setState(() { _isRecording = false; _isAnalyzing = true; });
    await _analyzeRecording();
  }

  Future<void> _analyzeRecording() async {
    if (_recordedFilePath == null) return;
    try {
      final api = ref.read(fastApiServiceProvider);
      final result = await api.analyzeSpeech(
        audioFilePath: _recordedFilePath!,
        expectedWord: _currentWord,
        childId: widget.childId,
      );
      if (mounted) setState(() { _analysisResult = result; _showResult = true; _isAnalyzing = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
  }

  // ── Save ────────────────────────────────────────────────────────────────
  Future<void> _saveResult() async {
    if (_analysisResult == null || _analysisUnavailable) return;
    setState(() => _isSaving = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final role = ref.read(userRoleProvider) ?? 'parent';
      final logId = fs.generateId('speechLogs');

      final log = SpeechLogModel(
        logId: logId, game: 'showAndTell', conductedBy: uid, conductorRole: role,
        date: DateTime.now(),
        score: _analysisResult!['matchScore'] as int? ?? 0,
        whisperTranscript: _analysisResult!['transcript'] as String?,
        expectedWord: _currentWord,
        matchScore: _analysisResult!['matchScore'] as int? ?? 0,
        clarityRating: _analysisResult!['clarityRating'] as String?,
        phonemesMissed: _analysisResult!['phonemesMissed'] != null
            ? List<String>.from(_analysisResult!['phonemesMissed'])
            : null,
        aiAnalysisSummary: _analysisResult!['feedbackMessage'] as String?,
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
          gameName: 'Show and Tell',
          score: log.score,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Result saved! ✓'), backgroundColor: HearTechColors.green),
        );
        _nextWord();
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

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider) ?? 'parent';
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: HearTechColors.deepTeal,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HearTechColors.white),
          onPressed: () =>
              closeSpeechScreen(context, role: role, fromGameScreen: true),
        ),
        title: Text('Show & Tell', style: HearTechTextStyles.appBarTitle(color: HearTechColors.white)),
        centerTitle: true,
        actions: [
          if (!_showResult && _currentPool.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: HearTechColors.white),
              tooltip: 'Next Word',
              onPressed: _nextWord,
            ),
        ],
      ),
      body: _isLoadingImages
          ? const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal))
          : SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Category Chips ───────────────────────────────────────────
          _buildCategoryChips(),
          const SizedBox(height: 20),

          if (_currentPool.isEmpty)
            _buildEmptyState()
          else if (_showResult && _analysisResult != null)
            _buildResultCard()
          else if (_isAnalyzing)
            _buildAnalyzingState()
          else
            _buildGameView(),
        ],
      ),
    );
  }

  // ── Category Chips ─────────────────────────────────────────────────────
  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: 8,
        children: _categories.map((cat) {
          final selected = cat == _selectedCategory;
          return FilterChip(
            label: Text(_categoryLabels[cat] ?? cat),
            selected: selected,
            onSelected: (_) => _selectCategory(cat),
            selectedColor: HearTechColors.deepTeal,
            backgroundColor: HearTechColors.paleTeal,
            labelStyle: HearTechTextStyles.caption(
              color: selected ? HearTechColors.white : HearTechColors.deepTeal,
            ).copyWith(fontWeight: FontWeight.w600),
            checkmarkColor: HearTechColors.white,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          );
        }).toList(),
      ),
    );
  }

  // ── Game View (image + mic) ────────────────────────────────────────────
  Widget _buildGameView() {
    return Column(
      children: [
        // Image display
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            color: HearTechColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: HearTechDecorations.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: _isEmoji
                ? Center(child: Text(
                    _emojiMap[_currentWord] ?? '❓',
                    style: const TextStyle(fontSize: 100),
                  ))
                : _isAssetImage
                    ? Image.asset(
                        _assetPath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) => Center(
                          child: Text(
                            _emojiMap[_currentWord] ?? '❓',
                            style: const TextStyle(fontSize: 100),
                          ),
                        ),
                      )
                : CachedNetworkImage(
                    imageUrl: _currentUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, progress) => Container(
                      color: HearTechColors.paleTeal,
                      child: const Center(child: CircularProgressIndicator(
                        color: HearTechColors.deepTeal, strokeWidth: 2)),
                    ),
                    errorWidget: (_, error, stackTrace) => Center(child: Text(
                      _emojiMap[_currentWord] ?? '❓',
                      style: const TextStyle(fontSize: 100),
                    )),
                  ),
          ),
        ).animate().scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOut,
        ),
        const SizedBox(height: 24),

        // Prompt
        Text(
          'What is this? Say it out loud!',
          style: HearTechTextStyles.sectionHeader(),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tip: say one English word only, then tap stop (max 5 seconds). Hold phone close, quiet room.',
          style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Mic Button
        GestureDetector(
          onTap: _toggleRecording,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isRecording) ...[
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.3), width: 3),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.4, 1.4), duration: 800.ms)
                    .fade(begin: 1, end: 0.2),
              ],
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _isRecording ? HearTechColors.white : HearTechColors.deepTeal,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: (_isRecording ? HearTechColors.coralRed : HearTechColors.deepTeal).withValues(alpha: 0.3),
                    blurRadius: 16, spreadRadius: 2,
                  )],
                  border: _isRecording ? Border.all(color: HearTechColors.coralRed, width: 3) : null,
                ),
                child: Icon(
                  Icons.mic,
                  size: 36,
                  color: _isRecording ? HearTechColors.coralRed : HearTechColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Timer / instruction
        if (_isRecording)
          Text(
            '0:${_elapsedSeconds.toString().padLeft(2, '0')}',
            style: HearTechTextStyles.sectionHeader(color: HearTechColors.coralRed)
                .copyWith(fontSize: 20),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 1, end: 0.5, duration: 800.ms)
        else
          Text('Tap to record', style: HearTechTextStyles.caption()),
        if (_countdownValue > 0) ...[
          const SizedBox(height: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HearTechColors.deepTeal.withValues(alpha: 0.12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$_countdownValue',
              style: HearTechTextStyles.screenTitle(color: HearTechColors.deepTeal),
            ),
          ).animate().scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 250.ms),
        ],
      ],
    );
  }

  // ── Analyzing State ────────────────────────────────────────────────────
  Widget _buildAnalyzingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          const CircularProgressIndicator(color: HearTechColors.deepTeal),
          const SizedBox(height: 20),
          Text('Analysing your response...', style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 8),
          Text(
            'Transcribing speech and checking clarity/phonemes',
            style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Result Card ────────────────────────────────────────────────────────
  Widget _buildResultCard() {
    final score = _analysisResult!['matchScore'] as int? ?? 0;
    final clarity = _analysisResult!['clarityRating'] as String? ?? 'Good';
    final transcript = _analysisResult!['transcript'] as String? ?? '';
    final missed = List<String>.from(_analysisResult!['phonemesMissed'] ?? []);
    final feedback = _analysisResult!['feedbackMessage'] as String? ?? '';
    final confidence = (score >= 90)
        ? 'High confidence'
        : (score >= 60)
            ? 'Moderate confidence'
            : 'Low confidence';

    final scoreColor = score >= 90 ? HearTechColors.green
        : score >= 60 ? HearTechColors.deepTeal
        : score >= 30 ? HearTechColors.warmOrange
        : HearTechColors.coralRed;

    final clarityColor = clarity == 'Excellent' ? HearTechColors.green
        : clarity == 'Good' ? HearTechColors.deepTeal
        : clarity == 'Needs Practice' ? HearTechColors.warmOrange
        : clarity == 'Unavailable' ? HearTechColors.coralRed
        : HearTechColors.coralRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: HearTechDecorations.cardBorderRadius,
        boxShadow: HearTechDecorations.cardShadow,
      ),
      child: Column(
        children: [
          // Score
          Text('$score%', style: HearTechTextStyles.bigNumber(color: scoreColor)),
          const SizedBox(height: 8),

          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100, minHeight: 10,
              color: scoreColor, backgroundColor: scoreColor.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 12),

          // Clarity badge
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: clarityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: clarityColor),
                ),
                child: Text(clarity, style: HearTechTextStyles.subtitle(color: clarityColor)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: HearTechColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: HearTechColors.purple.withValues(alpha: 0.4)),
                ),
                child: Text(
                  confidence,
                  style: HearTechTextStyles.caption(color: HearTechColors.purple)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Transcript
          Text(
            'We heard: "$transcript"',
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary)
                .copyWith(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),

          // Phonemes missed
          if (missed.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Phonemes missed:', style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                  .copyWith(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: missed.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HearTechColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('/$p/', style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                    .copyWith(fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],

          // Feedback
          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(feedback, style: HearTechTextStyles.body(), textAlign: TextAlign.center),
          ],
          if (_analysisUnavailable) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HearTechColors.coralRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Analysis could not be completed. Results were not saved — please record again.',
                style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                    .copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (!_analysisUnavailable) ...[
            const SizedBox(height: 8),
            Text(
              score >= 60
                  ? 'Great effort. Save and continue to the next word.'
                  : 'Try again slowly with clear pronunciation, then save your best attempt.',
              style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),

          // Buttons
          HearTechButton(
            label: 'Try Another Word',
            isSecondary: true,
            onPressed: _nextWord,
          ),
          if (!_analysisUnavailable) ...[
            const SizedBox(height: 10),
          HearTechButton(
            label: _isSaving ? 'Saving...' : 'Save and Continue',
            onPressed: (_isSaving || _analysisUnavailable) ? null : _saveResult,
          ),
          ],
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        children: [
          Icon(Icons.image_not_supported, size: 48, color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No images available', style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 4),
          Text(
            _imageLoadMessage.isNotEmpty
                ? _imageLoadMessage
                : 'Try a different category or upload images to Cloudinary.',
            style: HearTechTextStyles.caption(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
