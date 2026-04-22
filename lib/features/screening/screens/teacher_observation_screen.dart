import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';

/// Teacher Observation Form — select a child, answer observation questions,
/// add optional note, review, and submit.
/// Features: clinical chip tags, back button in questionnaire, character count
/// on note, child header in review, stagger animations.
class TeacherObservationScreen extends ConsumerStatefulWidget {
  const TeacherObservationScreen({super.key});

  @override
  ConsumerState<TeacherObservationScreen> createState() => _TeacherObservationScreenState();
}

class _TeacherObservationScreenState extends ConsumerState<TeacherObservationScreen> {
  ChildModel? _selectedChild;
  int _questionIndex = 0;
  bool _isLoading = false;
  bool _isDone = false;
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  final List<ObservationAnswer> _answers = [];
  String? _selectedResponse;

  final List<String> _responseOptions = ['always', 'often', 'sometimes', 'rarely', 'never'];

  int get _step {
    if (_selectedChild == null) return 0;
    if (_isLoading && _questions.isEmpty) return 5; // Loading questions
    if (_isDone) return 6;
    if (_questionIndex < _questions.length) return 1;
    if (_questionIndex == _questions.length) return 2; // Note step
    return 3; // Review step
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _selectResponse(String answer) {
    setState(() => _selectedResponse = answer);
  }

  void _confirmAnswer() {
    if (_selectedResponse == null) return;
    final q = _questions[_questionIndex];
    _answers.add(ObservationAnswer(
      questionId: q['id'] as String? ?? 'unk',
      questionText: q['q'] as String? ?? 'Unknown Question',
      answer: _selectedResponse!,
    ));
    _selectedResponse = null;

    if (_questionIndex < _questions.length - 1) {
      setState(() => _questionIndex++);
    } else {
      setState(() => _questionIndex = _questions.length); // note step
    }
  }

  void _goBack() {
    if (_questionIndex > 0 && _questionIndex <= _questions.length) {
      setState(() {
        _questionIndex--;
        if (_answers.isNotEmpty) _answers.removeLast();
        _selectedResponse = null;
      });
    } else if (_questionIndex == _questions.length) {
      // Back from note step
      setState(() {
        _questionIndex = _questions.length - 1;
        if (_answers.isNotEmpty) _answers.removeLast();
        _selectedResponse = null;
      });
    }
  }

  Future<void> _fetchQuestions(ChildModel child) async {
    setState(() {
      _selectedChild = child;
      _isLoading = true;
    });

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final res = await fastApi.getQuestionnaire(role: 'teacher', bracketId: child.ageBracket);
      if (mounted) {
        setState(() {
          final fetched = List<Map<String, dynamic>>.from(res['questions'] ?? []);
          _questions = fetched.map((q) => {
            'id': q['id'],
            'q': q['text'],
            'clinical': q['isClinical'] ?? false,
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load questions: $e'),
                backgroundColor: HearTechColors.coralRed));
        setState(() => _selectedChild = null);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedChild == null) return;
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final authService = ref.read(firebaseAuthServiceProvider);
      final fastApi = ref.read(fastApiServiceProvider);

      final teacherUid = authService.uid!;
      final child = await firestoreService.getChild(_selectedChild!.childId);
      if (child == null) throw Exception("Child not found");

      final previousRiskLevel = child.riskLevel;

      final apiAnswers = _answers.map((a) {
        final qMatched = _questions.firstWhere(
            (q) => q['id'] == a.questionId,
            orElse: () => {'clinical': false});
        return {
          'questionId': a.questionId,
          'answer': a.answer,
          'isClinical': qMatched['clinical'],
        };
      }).toList();

      final response = await fastApi.calculateRiskScore(
        answers: apiAnswers,
        ageBracket: child.ageBracket,
        conductorRole: 'teacher',
        childId: child.childId,
      );

      final newRiskScore = response['riskScore'] as int;
      final newRiskLevel = response['riskLevel'] as String;

      final obsId = firestoreService.generateId('observations');
      final obs = TeacherObservationModel(
        obsId: obsId,
        teacherUid: teacherUid,
        date: DateTime.now(),
        ageBracket: child.ageBracket,
        answers: _answers,
        openNote: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        riskScoreContribution: newRiskScore,
      );

      await firestoreService.addTeacherObservation(child.childId, obs);

      // Update child document
      await firestoreService.updateChild(child.childId, {
        'riskScore': newRiskScore,
        'riskLevel': newRiskLevel,
        'lastTeacherObservationDate': DateTime.now().toIso8601String(),
      });

      // ALWAYS fire HCW-04 and PAR-07
      if (child.hcwIds.isNotEmpty) {
        await fastApi.sendNotification(
          uid: child.hcwIds.first,
          type: 'HCW-04',
          title: 'New Teacher Observation',
          body: 'A new classroom observation was submitted for ${child.name}.',
          relatedChildId: child.childId,
        );
      }
      if (child.parentId != null) {
        await fastApi.sendNotification(
          uid: child.parentId!,
          type: 'PAR-07',
          title: 'New Classroom Observation',
          body: 'The teacher submitted a new observation for ${child.name}.',
          relatedChildId: child.childId,
        );
      }

      // IF Risk Level changed — fire HIGH priority
      if (previousRiskLevel != newRiskLevel) {
        if (child.hcwIds.isNotEmpty) {
          await fastApi.sendNotification(
            uid: child.hcwIds.first,
            type: 'HCW-05',
            priority: 'high',
            title: 'Risk Level Elevated — Review Required',
            body: 'Risk level for ${child.name} changed to $newRiskLevel.',
            relatedChildId: child.childId,
          );
        }
        if (child.parentId != null) {
          await fastApi.sendNotification(
            uid: child.parentId!,
            type: 'PAR-04',
            priority: 'high',
            title: 'Health Alert for ${child.name}',
            body: 'Risk level for ${child.name} changed to $newRiskLevel.',
            relatedChildId: child.childId,
          );
        }
      }

      setState(() => _isDone = true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Observation submitted for ${child.name}. '
                'The parent and healthcare provider have been notified.'),
            backgroundColor: HearTechColors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _body() {
    switch (_step) {
      case 0: return _buildChildSelection();
      case 1: return _buildQuestion();
      case 2: return _buildNote();
      case 3: return _buildReview();
      case 5: return const Center(child: LoadingIndicator(message: 'Loading questions...'));
      case 6: return _buildDone();
      default: return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.teacherDashboard),
        ),
        title: Text('Classroom Observation', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  // ── Step 0: Select Child ──────────────────────────────────────────────────
  Widget _buildChildSelection() {
    final childrenAsync = ref.watch(teacherChildrenProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select a Student', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Choose which student this observation is for.',
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: childrenAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (children) {
                if (children.isEmpty) {
                  return Center(
                    child: Text('No students linked to your account.',
                        style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                  );
                }
                return ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    return GestureDetector(
                      onTap: () => _fetchQuestions(child),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HearTechColors.white,
                          borderRadius: HearTechDecorations.cardBorderRadius,
                          boxShadow: HearTechDecorations.cardShadow,
                        ),
                        child: Row(
                          children: [
                            AvatarCircle(name: child.name, photoUrl: child.profilePhotoUrl, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(child.name, style: HearTechTextStyles.subtitle()),
                                  Text(child.ageString, style: HearTechTextStyles.caption()),
                                ],
                              ),
                            ),
                            RiskBadge(riskLevel: child.riskLevel),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, color: HearTechColors.textSecondary),
                          ],
                        ),
                      ),
                    ).animate(delay: (index * 80).ms)
                        .fadeIn(duration: 200.ms)
                        .slideX(begin: -0.05, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Question ──────────────────────────────────────────────────────
  Widget _buildQuestion() {
    final q = _questions[_questionIndex];
    final questionText = q['q'] as String? ?? '';
    final isClinical = q['clinical'] == true;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScreeningProgressBar(current: _questionIndex + 1, total: _questions.length),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Clinical chip tag
                  if (isClinical)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: HearTechColors.coralRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Clinical',
                          style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                              .copyWith(fontWeight: FontWeight.w700)),
                    ),
                  Text(questionText,
                      style: HearTechTextStyles.screenTitle(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),

                  // Response chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _responseOptions.map((opt) {
                      final isSelected = _selectedResponse == opt;
                      return ChoiceChip(
                        label: Text(opt[0].toUpperCase() + opt.substring(1)),
                        selected: isSelected,
                        selectedColor: HearTechColors.deepTeal,
                        backgroundColor: HearTechColors.paleTeal,
                        labelStyle: HearTechTextStyles.body(
                          color: isSelected ? HearTechColors.white : HearTechColors.deepTeal,
                        ),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (_) => _selectResponse(opt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_questionIndex > 0)
                Expanded(
                  child: HearTechButton(
                    label: 'Back',
                    onPressed: _goBack,
                    isSecondary: true,
                  ),
                ),
              if (_questionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: HearTechButton(
                  label: _questionIndex < _questions.length - 1 ? 'Next' : 'Continue',
                  onPressed: _selectedResponse != null ? _confirmAnswer : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 2: Note ──────────────────────────────────────────────────────────
  Widget _buildNote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Any additional observations?', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Optional — share anything else about this student.',
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _noteController,
            maxLines: 6,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. The child seems to struggle more in noisy hallways...',
              hintStyle: HearTechTextStyles.caption(),
              filled: true,
              fillColor: HearTechColors.paleTeal,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: HearTechColors.deepTeal, width: 2),
              ),
              counterText: '${_noteController.text.length}/500',
              counterStyle: HearTechTextStyles.caption(),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: HearTechButton(
                  label: 'Back',
                  onPressed: _goBack,
                  isSecondary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HearTechButton(
                  label: 'Continue to Review',
                  onPressed: () {
                    setState(() => _questionIndex = _questions.length + 1);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3: Review ────────────────────────────────────────────────────────
  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Child header
          if (_selectedChild != null) ...[
            Row(
              children: [
                AvatarCircle(name: _selectedChild!.name, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${_selectedChild!.name} — Observation Summary',
                          style: HearTechTextStyles.sectionHeader()),
                      Text(_selectedChild!.ageString,
                          style: HearTechTextStyles.caption()),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Edit button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _questionIndex = 0;
                  _answers.clear();
                  _selectedResponse = null;
                });
              },
              icon: const Icon(Icons.edit, size: 16, color: HearTechColors.deepTeal),
              label: Text('Edit Answers',
                  style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),

          // Answer list
          ..._answers.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q${entry.key + 1}. ${entry.value.questionText}',
                      style: HearTechTextStyles.body()),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(entry.value.answer.toUpperCase(),
                        style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)
                            .copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          )),

          // Open note
          if (_noteController.text.trim().isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text('Additional Note:', style: HearTechTextStyles.subtitle()),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_noteController.text.trim(), style: HearTechTextStyles.body()),
            ),
          ],
          const SizedBox(height: 32),
          HearTechButton(
            label: 'Submit Observation',
            onPressed: _submit,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // ── Step 6: Done ──────────────────────────────────────────────────────────
  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 64, color: HearTechColors.green),
            ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Observation Submitted!', style: HearTechTextStyles.screenTitle())
                .animate(delay: 200.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            Text('Thank you for helping monitor this student.',
                style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                textAlign: TextAlign.center)
                .animate(delay: 300.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 32),
            HearTechButton(
              label: 'Back to Dashboard',
              onPressed: () => context.go(Routes.teacherDashboard),
            ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}
