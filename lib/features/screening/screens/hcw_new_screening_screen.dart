import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';
import 'package:heartech/shared/widgets/risk_gauge.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';

/// HCW Screening — Full 7-step flow per master build prompt:
///   Step 1: Child info + DOB + age bracket detection + gender
///   Step 2: Questionnaire (4 responses: YES/PARTIAL/NO/NOT SURE)
///   Step 3: Clinical note
///   Step 4: Processing animation
///   Step 5A: Low-risk result (confetti, anonymous save)
///   Step 5B: Med/High-risk result (flagged questions, create profile CTA)
///   Step 6: Child profile creation form (after tapping Create Profile)
///   Step 7: Referral prompt modal
class HcwNewScreeningScreen extends ConsumerStatefulWidget {
  const HcwNewScreeningScreen({super.key});

  @override
  ConsumerState<HcwNewScreeningScreen> createState() => _HcwNewScreeningScreenState();
}

class _HcwNewScreeningScreenState extends ConsumerState<HcwNewScreeningScreen> {
  // ── Phase: 0=child info, 1=questionnaire, 2=clinical note,
  // 3=processing, 4=result, 5=profile creation, 6=referral prompt ──
  int _step = 0;
  int _questionIndex = 0;
  bool _isLoading = false;

  // Step 1: Child info
  final _nameCtrl = TextEditingController();
  DateTime? _dob;
  String? _gender;

  // Medical history
  bool _premature = false;
  bool _nicu = false;
  bool _familyHistory = false;
  int _earInfections = 0;

  // Step 2: Questions & answers
  final List<ScreeningAnswer> _answers = [];
  String? _selectedAnswer; // Tracks current question's selected response

  // Step 3: Clinical note
  final _noteCtrl = TextEditingController();

  // Step 4-5: Result
  double _riskScore = 0;
  String _riskLevel = 'low';
  String? _createdChildId;
  String? _handoverCode;

  // Dynamic questions based on age bracket
  List<Map<String, dynamic>> _questions = [];

  int _computeAgeBracket() {
    if (_dob == null) return 1;
    final months = DateTime.now().difference(_dob!).inDays ~/ 30;
    if (months <= 6) return 1;
    if (months <= 12) return 2;
    if (months <= 24) return 3;
    if (months <= 60) return 4;
    return 5;
  }

  String _bracketLabel(int bracket) {
    switch (bracket) {
      case 1: return 'Bracket 1 — Newborn (0-6 months)';
      case 2: return 'Bracket 2 — Older Infant (7-12 months)';
      case 3: return 'Bracket 3 — Toddler (1-2 years)';
      case 4: return 'Bracket 4 — Preschool (3-5 years)';
      case 5: return 'Bracket 5 — School Age (6-12 years)';
      default: return 'Unknown';
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final bracket = _computeAgeBracket();
      final res = await fastApi.getQuestionnaire(role: 'hcw', bracketId: bracket);
      if (mounted) {
        setState(() {
          final fetched = List<Map<String, dynamic>>.from(res['questions'] ?? []);
          // Map backend keys (text, isClinical) to local keys (q, clinical) for ease
          _questions = fetched.map((q) => <String, dynamic>{
            'id': q['id'],
            'q': q['text'],
            'clinical': q['isClinical'] ?? false,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e'), backgroundColor: HearTechColors.coralRed));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startScreening() async {
    if (_nameCtrl.text.trim().isEmpty || _dob == null || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }
    await _loadQuestions();
    if (_questions.isNotEmpty && mounted) {
      setState(() => _step = 1);
    }
  }

  void _answerQuestion(String answer) {
    _answers.add(ScreeningAnswer(
      questionId: _questions[_questionIndex]['id'],
      questionText: _questions[_questionIndex]['q'],
      answer: answer,
    ));
    _selectedAnswer = null;

    if (_questionIndex < _questions.length - 1) {
      setState(() => _questionIndex++);
    } else {
      // Move to clinical note
      setState(() => _step = 2);
    }
  }

  void _goBack() {
    if (_questionIndex > 0) {
      _answers.removeLast();
      setState(() {
        _questionIndex--;
        _selectedAnswer = null;
      });
    } else {
      setState(() => _step = 0);
    }
  }

  Future<void> _analyseResults() async {
    setState(() => _step = 3); // processing
    await _calculateScore();
    if (mounted) setState(() => _step = 4); // result
  }

  Future<void> _calculateScore() async {
    try {
      final fastApi = ref.read(fastApiServiceProvider);
      
      // Map local answers format to what backend expects
      final apiAnswers = _answers.map((a) {
        final qMatched = _questions.firstWhere((q) => q['id'] == a.questionId, orElse: () => {'clinical': false});
        return {
          'questionId': a.questionId,
          'answer': a.answer,
          'isClinical': qMatched['clinical'],
        };
      }).toList();

      final response = await fastApi.calculateRiskScore(
        answers: apiAnswers,
        ageBracket: _computeAgeBracket(),
        conductorRole: 'hcw',
        childMetadata: {
          'medicalHistory': {
            'prematureBirth': _premature,
            'nicuAdmission': _nicu,
            'familyHistoryHearingLoss': _familyHistory,
            'earInfectionCount': _earInfections,
          },
        },
      );
      
      if (mounted) {
        setState(() {
          _riskScore = (response['riskScore'] as num).toDouble();
          _riskLevel = response['riskLevel'] as String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scoring error: $e'), backgroundColor: HearTechColors.coralRed));
      }
    }
  }

  Future<void> _saveAnonymous() async {
    setState(() => _isLoading = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final id = fs.generateId(FirestorePaths.hcwScreenings);

      await fs.saveHcwScreening(id, {
        'screeningId': id,
        'hcwId': uid,
        'sessionChildName': _nameCtrl.text.trim(),
        'sessionDob': Timestamp.fromDate(_dob!),
        'sessionGender': _gender,
        'ageBracket': _computeAgeBracket(),
        'answers': _answers.map((a) => a.toJson()).toList(),
        'riskScore': _riskScore.round(),
        'riskLevel': _riskLevel,
        'clinicalNote': _noteCtrl.text.trim(),
        'createdAt': Timestamp.now(),
        'profileCreated': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anonymous record saved.'), backgroundColor: HearTechColors.green),
        );
        context.go(Routes.hcwDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _createChildProfile() async {
    setState(() { _step = 5; _isLoading = true; });
    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final childId = fs.generateId(FirestorePaths.children);
      final screeningId = fs.generateId('screenings');
      final code = _makeCode();
      final now = DateTime.now();
      final bracket = _computeAgeBracket();

      final child = ChildModel(
        childId: childId,
        name: _nameCtrl.text.trim(),
        dob: _dob!,
        gender: _gender!,
        ageBracket: bracket,
        createdByHcwId: uid,
        hcwIds: [uid],
        riskScore: _riskScore.round(),
        riskLevel: _riskLevel,
        createdAt: now,
        lastUpdatedAt: now,
        lastScreeningDate: now,
        medicalHistory: MedicalHistory(
          prematureBirth: _premature,
          nicuAdmission: _nicu,
          familyHistoryHearingLoss: _familyHistory,
          earInfectionCount: _earInfections,
        ),
        handoverCode: HandoverCode(
          code: code,
          createdAt: now,
          expiresAt: now.add(const Duration(hours: 24)),
        ),
      );
      await fs.setChild(child);

      final screening = ScreeningModel(
        screeningId: screeningId,
        conductedBy: uid,
        conductorRole: 'hcw',
        date: now,
        ageBracket: bracket,
        answers: _answers,
        riskScore: _riskScore.round(),
        riskLevel: _riskLevel,
        clinicalNote: _noteCtrl.text.trim(),
      );
      await fs.addScreening(childId, screening);

      _createdChildId = childId;
      _handoverCode = code;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  String _makeCode() {
    // Exclude 0, O, I, 1 for readability per prompt
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HearTechColors.textPrimary),
          onPressed: _showExitDialog,
        ),
        title: Text(_stepTitle(), style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 0: return 'Child Information';
      case 1: return 'Screening Questions';
      case 2: return 'Clinical Note';
      case 3: return 'Processing...';
      case 4: return 'Result';
      case 5: return 'Handover Code';
      default: return 'Screening';
    }
  }

  Widget _body() {
    switch (_step) {
      case 0: return _buildStep1ChildInfo();
      case 1: return _buildStep2Questionnaire();
      case 2: return _buildStep3ClinicalNote();
      case 3: return _buildStep4Processing();
      case 4: return _buildStep5Result();
      case 5: return _buildStep6HandoverCode();
      default: return const SizedBox.shrink();
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Screening?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); context.go(Routes.hcwDashboard); },
            child: const Text('Exit', style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
  }

  // ── STEP 1: Child Info ─────────────────────────────────────────────────
  Widget _buildStep1ChildInfo() {
    final bracket = _dob != null ? _computeAgeBracket() : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teal gradient header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Screening', style: HearTechTextStyles.screenTitle(color: HearTechColors.white)),
                const SizedBox(height: 4),
                Text("Enter the child's basic information to begin.",
                    style: HearTechTextStyles.caption(color: HearTechColors.white.withValues(alpha: 0.85))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HearTechColors.paleTeal,
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: HearTechColors.deepTeal),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No profile will be created until the screening is complete.',
                    style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          HearTechInputField(controller: _nameCtrl, label: "Child's Full Name", prefixIcon: Icons.child_care),
          const SizedBox(height: 16),

          // DOB picker
          GestureDetector(
            onTap: _pickDob,
            child: AbsorbPointer(
              child: HearTechInputField(
                label: 'Date of Birth', prefixIcon: Icons.calendar_today_outlined,
                controller: TextEditingController(
                  text: _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : '',
                ),
                hint: 'Tap to select',
              ),
            ),
          ),

          // Age bracket chip (real-time detection)
          if (bracket != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_fix_high, size: 16, color: HearTechColors.deepTeal),
                  const SizedBox(width: 6),
                  Text('Detected: ${_bracketLabel(bracket)}',
                      style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)
                          .copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
          const SizedBox(height: 16),

          // Gender chips
          Text('Gender', style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: ['Boy', 'Girl', 'Prefer not to say'].map((g) {
              final selected = _gender == g;
              return ChoiceChip(
                label: Text(g),
                selected: selected,
                onSelected: (v) => setState(() => _gender = v ? g : null),
                selectedColor: HearTechColors.deepTeal,
                labelStyle: TextStyle(color: selected ? HearTechColors.white : HearTechColors.textPrimary),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Medical history
          Text('Medical History', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 12),
          _MedToggle(label: 'Premature Birth', value: _premature,
              onChanged: (v) => setState(() => _premature = v ?? false)),
          _MedToggle(label: 'NICU Admission', value: _nicu,
              onChanged: (v) => setState(() => _nicu = v ?? false)),
          _MedToggle(label: 'Family History of Hearing Loss', value: _familyHistory,
              onChanged: (v) => setState(() => _familyHistory = v ?? false)),
          Row(children: [
            Text('Ear Infections:', style: HearTechTextStyles.body()),
            const SizedBox(width: 12),
            IconButton(onPressed: () { if (_earInfections > 0) setState(() => _earInfections--); },
                icon: const Icon(Icons.remove_circle_outline, color: HearTechColors.deepTeal)),
            Text('$_earInfections', style: HearTechTextStyles.subtitle()),
            IconButton(onPressed: () { if (_earInfections < 10) setState(() => _earInfections++); },
                icon: const Icon(Icons.add_circle_outline, color: HearTechColors.deepTeal)),
          ]),
          const SizedBox(height: 32),

          HearTechButton(label: 'Start Screening', onPressed: _startScreening),
        ],
      ),
    );
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      firstDate: DateTime(2010), lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  // ── STEP 2: Questionnaire (4 response cards) ──────────────────────────
  Widget _buildStep2Questionnaire() {
    final q = _questions[_questionIndex];
    final isClinical = q['clinical'] as bool;
    final isLastQuestion = _questionIndex == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScreeningProgressBar(current: _questionIndex + 1, total: _questions.length),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Question ${_questionIndex + 1} of ${_questions.length}',
                  style: HearTechTextStyles.caption()),
              Text('Bracket ${_computeAgeBracket()}',
                  style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
            ],
          ),
          if (isClinical) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HearTechColors.coralRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Clinical', style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                  .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(q['q'] as String, style: HearTechTextStyles.screenTitle(),
                      textAlign: TextAlign.center)
                      .animate().fadeIn(duration: 200.ms),
                  const SizedBox(height: 24),

                  // 4 response cards — select, don't auto-advance
                  _SelectableResponseCard(
                    label: 'Yes', color: HearTechColors.green,
                    icon: Icons.check_circle_outline,
                    selected: _selectedAnswer == 'yes',
                    onTap: () => setState(() => _selectedAnswer = 'yes'),
                  ),
                  const SizedBox(height: 10),
                  _SelectableResponseCard(
                    label: 'Partial', color: HearTechColors.warmOrange,
                    icon: Icons.change_history,
                    selected: _selectedAnswer == 'partial',
                    onTap: () => setState(() => _selectedAnswer = 'partial'),
                  ),
                  const SizedBox(height: 10),
                  _SelectableResponseCard(
                    label: 'No', color: HearTechColors.coralRed,
                    icon: Icons.cancel_outlined,
                    selected: _selectedAnswer == 'no',
                    onTap: () => setState(() => _selectedAnswer = 'no'),
                  ),
                  const SizedBox(height: 10),
                  _SelectableResponseCard(
                    label: 'Not Sure', color: HearTechColors.textSecondary,
                    icon: Icons.help_outline,
                    selected: _selectedAnswer == 'not_sure',
                    onTap: () => setState(() => _selectedAnswer = 'not_sure'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Navigation buttons
          Row(
            children: [
              if (_questionIndex > 0)
                Expanded(
                  child: TextButton.icon(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                  ),
                ),
              if (_questionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: HearTechButton(
                  label: isLastQuestion ? 'Submit and Analyse' : 'Next',
                  onPressed: _selectedAnswer != null
                      ? () => _answerQuestion(_selectedAnswer!)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── STEP 3: Clinical Note ─────────────────────────────────────────────
  Widget _buildStep3ClinicalNote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Clinical Notes', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Add any relevant clinical observations or notes about this screening session.',
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 24),

          TextFormField(
            controller: _noteCtrl,
            maxLines: 8,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Type your clinical notes here...',
              filled: true,
              fillColor: HearTechColors.paleTeal,
              border: OutlineInputBorder(borderRadius: HearTechDecorations.inputBorderRadius, borderSide: BorderSide.none),
            ),
          ),

          // Required for high risk
          if (_answers.where((a) => a.answer == 'no').length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('⚠ Clinical note is strongly recommended for this screening.',
                  style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)),
            ),

          const SizedBox(height: 32),
          HearTechButton(label: 'Analyse Results', onPressed: _analyseResults),
        ],
      ),
    );
  }

  // ── STEP 4: Processing Animation ──────────────────────────────────────
  Widget _buildStep4Processing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing ear icon
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: HearTechColors.deepTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hearing, size: 64, color: HearTechColors.deepTeal),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
          const SizedBox(height: 32),
          Text('Analysing responses...', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Please wait while we process the screening data.',
              style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: HearTechColors.deepTeal),
        ],
      ),
    );
  }

  // ── STEP 5: Result (Low vs Med/High split) ────────────────────────────
  Widget _buildStep5Result() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }

    final isLow = _riskLevel == 'low';
    final accentColor = _riskLevel == 'high' ? HearTechColors.coralRed
        : _riskLevel == 'medium' ? HearTechColors.warmOrange : HearTechColors.green;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Risk gauge
          RiskGauge(score: _riskScore.round(), riskLevel: _riskLevel, size: 180),
          const SizedBox(height: 16),
          RiskBadge(riskLevel: _riskLevel),
          const SizedBox(height: 24),

          if (isLow) ...[
            // LOW RISK — Step 5A
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HearTechColors.green.withValues(alpha: 0.08),
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: HearTechColors.green.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                const Icon(Icons.check_circle, size: 48, color: HearTechColors.green),
                const SizedBox(height: 12),
                Text('Low Risk Detected', style: HearTechTextStyles.screenTitle(color: HearTechColors.green)),
                const SizedBox(height: 8),
                Text('No immediate hearing concerns detected.',
                    style: HearTechTextStyles.body(color: HearTechColors.textSecondary), textAlign: TextAlign.center),
              ]),
            ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
            const SizedBox(height: 16),

            // 3 positive recommendations
            _RecommendationTile(icon: Icons.thumb_up, text: 'Continue regular hearing check-ups as your child grows.'),
            _RecommendationTile(icon: Icons.music_note, text: 'Expose your child to music and varied sounds for development.'),
            _RecommendationTile(icon: Icons.calendar_today, text: 'Schedule a follow-up in 6-12 months for continued monitoring.'),
            const SizedBox(height: 24),

            HearTechButton(label: 'Save Anonymous Record', onPressed: _saveAnonymous, isSecondary: true),
            const SizedBox(height: 12),
            HearTechButton(label: 'Done', onPressed: () => context.go(Routes.hcwDashboard)),
          ] else ...[
            // MEDIUM/HIGH RISK — Step 5B
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Icon(Icons.warning_amber, size: 48, color: accentColor),
                const SizedBox(height: 12),
                Text('Concerning result detected.',
                    style: HearTechTextStyles.screenTitle(color: accentColor)),
                const SizedBox(height: 8),
                Text('Child: ${_nameCtrl.text.trim()}',
                    style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 16),

            // Flagged questions
            Text('Flagged Responses', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 8),
            ..._answers.where((a) => a.answer == 'no' || a.answer == 'partial').map((a) =>
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HearTechColors.coralRed.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Icon(Icons.flag, size: 18, color: accentColor),
                    const SizedBox(width: 8),
                    Expanded(child: Text(a.questionText, style: HearTechTextStyles.caption())),
                    Text(a.answer.toUpperCase(), style: HearTechTextStyles.label(color: accentColor)),
                  ]),
                ),
            ),
            const SizedBox(height: 24),

            HearTechButton(label: 'Create Child Profile', onPressed: _createChildProfile),
            const SizedBox(height: 12),
            HearTechButton(label: 'Save Record Only', onPressed: _saveAnonymous, isSecondary: true),
          ],

          const SizedBox(height: 24),
          const DisclaimerFooter(),
        ],
      ),
    );
  }

  // ── STEP 6: Handover Code Display ─────────────────────────────────────
  Widget _buildStep6HandoverCode() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.check_circle, size: 64, color: HearTechColors.green),
          const SizedBox(height: 16),
          Text('Profile Created!', style: HearTechTextStyles.screenTitle(color: HearTechColors.green)),
          const SizedBox(height: 8),
          Text('Share this code with the parent', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 32),

          // 6-character code boxes
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: HearTechColors.warmOrange.withValues(alpha: 0.1),
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text('Handover Code', style: HearTechTextStyles.subtitle(color: HearTechColors.warmOrange)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_handoverCode?.length ?? 0, (i) {
                    return Container(
                      width: 44, height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: HearTechColors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.5)),
                      ),
                      child: Center(
                        child: Text(
                          _handoverCode![i],
                          style: HearTechTextStyles.handoverCode(),
                        ),
                      ),
                    ).animate(delay: (i * 80).ms).scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      duration: 300.ms,
                      curve: Curves.elasticOut,
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: HearTechColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('Expires in 24 hours', style: HearTechTextStyles.caption()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          HearTechButton(
            label: 'View Child Profile',
            onPressed: () {
              if (_createdChildId != null) {
                context.go(Routes.hcwChildProfile.replaceFirst(':childId', _createdChildId!));
              }
            },
          ),
          const SizedBox(height: 12),
          HearTechButton(
            label: 'Back to Dashboard',
            onPressed: () => context.go(Routes.hcwDashboard),
            isSecondary: true,
          ),
          const SizedBox(height: 12),

          // Step 7: Referral prompt
          if (_riskLevel == 'high')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HearTechColors.coralRed.withValues(alpha: 0.06),
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.2)),
              ),
              child: Column(children: [
                Text('Generate a clinical referral for ${_nameCtrl.text.trim()}?',
                    style: HearTechTextStyles.subtitle(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                HearTechButton(
                  label: 'Generate Referral',
                  onPressed: () {
                    if (_createdChildId != null) {
                      context.go(
                        Routes.referralGeneration
                            .replaceFirst(':childId', _createdChildId!)
                            .replaceFirst(':screeningId', 'latest'),
                      );
                    }
                  },
                  backgroundColor: HearTechColors.coralRed,
                ),
              ]),
            ),

          const SizedBox(height: 24),
          const DisclaimerFooter(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _MedToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
  const _MedToggle({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value, onChanged: onChanged,
      title: Text(label, style: HearTechTextStyles.body()),
      activeColor: HearTechColors.deepTeal,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero, dense: true,
    );
  }
}

class _SelectableResponseCard extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableResponseCard({required this.label, required this.color, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? 0.15 : 0.06),
          borderRadius: HearTechDecorations.cardBorderRadius,
          border: Border.all(
            color: selected ? HearTechColors.deepTeal : color.withValues(alpha: 0.2),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: HearTechTextStyles.subtitle(color: color).copyWith(fontWeight: FontWeight.w700)),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: HearTechColors.deepTeal, size: 22),
          ],
        ),
      ),
    );
  }
}


class _RecommendationTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _RecommendationTile({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: HearTechColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: HearTechTextStyles.body())),
        ],
      ),
    );
  }
}
