import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';

/// Teacher Observation Form — select a child, answer 10 observation questions.
class TeacherObservationScreen extends ConsumerStatefulWidget {
  const TeacherObservationScreen({super.key});

  @override
  ConsumerState<TeacherObservationScreen> createState() => _TeacherObservationScreenState();
}

class _TeacherObservationScreenState extends ConsumerState<TeacherObservationScreen> {
  String? _selectedChildId;
  int _questionIndex = 0;
  bool _isLoading = false;
  bool _isDone = false;
  final _noteController = TextEditingController();

  List<Map<String, dynamic>> _questions = [];
  final List<ObservationAnswer> _answers = [];
  final List<String> _responseOptions = ['always', 'often', 'sometimes', 'rarely', 'never'];

  int get _step {
    if (_selectedChildId == null) return 0;
    if (_isLoading) return 5; 
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

  void _answerQuestion(String answer) {
    final q = _questions[_questionIndex];
    _answers.add(ObservationAnswer(
      questionId: q['id'] as String? ?? 'unk',
      questionText: q['q'] as String? ?? 'Unknown Question',
      answer: answer,
    ));

    if (_questionIndex < _questions.length - 1) {
      setState(() => _questionIndex++);
    } else {
      // Show note step
      setState(() => _questionIndex = _questions.length); // note step
    }
  }

  Future<void> _fetchQuestions(ChildModel child) async {
    setState(() {
      _selectedChildId = child.childId;
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
            'clinical': q['isClinical'],
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load questions: $e'), backgroundColor: HearTechColors.coralRed));
        setState(() => _selectedChildId = null); // Reset
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedChildId == null) return;
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final authService = ref.read(firebaseAuthServiceProvider);
      final fastApi = ref.read(fastApiServiceProvider);

      final teacherUid = authService.uid!;
      final child = await firestoreService.getChild(_selectedChildId!);
      if (child == null) throw Exception("Child not found");

      final previousRiskLevel = child.riskLevel;

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
        openNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      await firestoreService.addTeacherObservation(child.childId, obs);

      // Update child document
      await firestoreService.updateChild(child.childId, {
        'riskScore': newRiskScore,
        'riskLevel': newRiskLevel,
        'lastTeacherObservationDate': DateTime.now().toIso8601String(), // or Timestamp based on model
      });

      // ALWAYS fire
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

      // IF Risk Changed
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
            content: Text('Observation submitted for ${child.name}. The parent and healthcare provider have been notified.'),
            backgroundColor: HearTechColors.green,
            duration: const Duration(seconds: 4),
          )
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
      case 5: return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
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
              style: HearTechTextStyles.caption()),
          const SizedBox(height: 24),
          Expanded(
            child: childrenAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal)),
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
                            const Icon(Icons.child_care, color: HearTechColors.deepTeal),
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
                            const Icon(Icons.chevron_right, color: HearTechColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_questionIndex];
    final questionText = q['q'] as String? ?? '';
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScreeningProgressBar(current: _questionIndex + 1, total: _questions.length),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Text(questionText, style: HearTechTextStyles.screenTitle(), textAlign: TextAlign.center),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _responseOptions.map((opt) {
              return ActionChip(
                label: Text(opt[0].toUpperCase() + opt.substring(1)),
                labelStyle: HearTechTextStyles.body(color: HearTechColors.deepTeal),
                side: const BorderSide(color: HearTechColors.deepTeal),
                backgroundColor: HearTechColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _answerQuestion(opt),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional Notes', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Anything else you want to share about this student? (Optional)',
              style: HearTechTextStyles.caption()),
          const SizedBox(height: 24),
          TextFormField(
            controller: _noteController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'e.g. The child seems to struggle more in noisy hallways...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: HearTechColors.deepTeal, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),
          HearTechButton(
            label: 'Continue to Review', 
            onPressed: () {
              setState(() => _questionIndex = _questions.length + 1);
            }
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review Observation', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Please review your answers before submitting.', style: HearTechTextStyles.caption()),
          const SizedBox(height: 24),
          ..._answers.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.questionText, style: HearTechTextStyles.body()),
                const SizedBox(height: 4),
                Text('Answer: ${a.answer.toUpperCase()}', 
                    style: HearTechTextStyles.caption(color: HearTechColors.deepTeal).copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          )),
          if (_noteController.text.trim().isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text('Note:', style: HearTechTextStyles.subtitle()),
            Text(_noteController.text.trim(), style: HearTechTextStyles.body()),
          ],
          const SizedBox(height: 32),
          HearTechButton(label: 'Submit Observation', onPressed: _submit, isLoading: _isLoading),
        ],
      ),
    );
  }

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
            ),
            const SizedBox(height: 24),
            Text('Observation Submitted!', style: HearTechTextStyles.screenTitle()),
            const SizedBox(height: 8),
            Text('Thank you for helping monitor this student.',
                style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            HearTechButton(
              label: 'Back to Dashboard',
              onPressed: () => context.go(Routes.teacherDashboard),
            ),
          ],
        ),
      ),
    );
  }
}
