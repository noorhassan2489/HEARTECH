import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';
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

  final List<Map<String, String>> _questions = [
    {'id': 'OBS-01', 'q': 'Does the child respond when their name is called in class?'},
    {'id': 'OBS-02', 'q': 'Does the child follow verbal directions the first time?'},
    {'id': 'OBS-03', 'q': 'Does the child frequently ask you to repeat instructions?'},
    {'id': 'OBS-04', 'q': 'Does the child lean forward or cup their ear to hear?'},
    {'id': 'OBS-05', 'q': 'Does the child participate in group discussions?'},
    {'id': 'OBS-06', 'q': 'Does the child get easily distracted by background noise?'},
    {'id': 'OBS-07', 'q': "Is the child's speech clear and age-appropriate?"},
    {'id': 'OBS-08', 'q': 'Does the child have difficulty with phonics or reading aloud?'},
    {'id': 'OBS-09', 'q': 'Does the child seem isolated or withdrawn from peers?'},
    {'id': 'OBS-10', 'q': 'Have you noticed any behavioral changes in the child recently?'},
  ];

  final List<ObservationAnswer> _answers = [];

  final List<String> _responseOptions = ['always', 'often', 'sometimes', 'rarely', 'never'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _answerQuestion(String answer) {
    _answers.add(ObservationAnswer(
      questionId: _questions[_questionIndex]['id']!,
      questionText: _questions[_questionIndex]['q']!,
      answer: answer,
    ));

    if (_questionIndex < _questions.length - 1) {
      setState(() => _questionIndex++);
    } else {
      // Show note step
      setState(() => _questionIndex = _questions.length); // note step
    }
  }

  Future<void> _submit() async {
    if (_selectedChildId == null) return;
    setState(() => _isLoading = true);

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final authService = ref.read(firebaseAuthServiceProvider);
      final teacherUid = authService.uid!;

      // Get the child for age bracket
      final child = await firestoreService.getChild(_selectedChildId!);
      final ageBracket = child?.ageBracket ?? 4;

      final obsId = firestoreService.generateId('observations');
      final obs = TeacherObservationModel(
        obsId: obsId,
        teacherUid: teacherUid,
        date: DateTime.now(),
        ageBracket: ageBracket,
        answers: _answers,
        openNote: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      );

      await firestoreService.addTeacherObservation(_selectedChildId!, obs);
      setState(() => _isDone = true);
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
          onPressed: () => context.go(Routes.teacherDashboard),
        ),
        title: Text('Classroom Observation', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isDone
            ? _buildDone()
            : _selectedChildId == null
                ? _buildChildSelection()
                : _questionIndex < _questions.length
                    ? _buildQuestion()
                    : _buildNote(),
      ),
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
                      onTap: () => setState(() => _selectedChildId = child.childId),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScreeningProgressBar(current: _questionIndex + 1, total: _questions.length),
          const SizedBox(height: 32),
          Expanded(
            child: Center(
              child: Text(q['q']!, style: HearTechTextStyles.screenTitle(), textAlign: TextAlign.center),
            ),
          ),
          Column(
            children: _responseOptions.map((opt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _answerQuestion(opt),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: HearTechColors.deepTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      opt[0].toUpperCase() + opt.substring(1),
                      style: HearTechTextStyles.body(color: HearTechColors.deepTeal),
                    ),
                  ),
                ),
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
