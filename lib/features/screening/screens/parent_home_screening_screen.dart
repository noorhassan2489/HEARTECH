import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';

/// Parent Home Screening — select child → questionnaire → plain-language result.
/// No clinical numbers visible to parent.
class ParentHomeScreeningScreen extends ConsumerStatefulWidget {
  const ParentHomeScreeningScreen({super.key});
  @override
  ConsumerState<ParentHomeScreeningScreen> createState() => _ParentHomeScreeningState();
}

class _ParentHomeScreeningState extends ConsumerState<ParentHomeScreeningScreen> {
  int _step = 0; // 0=select child, 1=questionnaire, 2=processing, 3=result
  int _qIndex = 0;
  ChildModel? _selectedChild;
  final List<ScreeningAnswer> _answers = [];
  String _riskLevel = 'low';
  List<Map<String, dynamic>> _questions = [];

  void _loadQuestions(int bracket) {
    final Map<int, List<Map<String, dynamic>>> parentQs = {
      1: [
        {'id': 'par1_q1', 'q': 'Does your baby startle, blink, or jump at sudden loud sounds?', 'clinical': false},
        {'id': 'par1_q2', 'q': 'Does your baby calm down when you talk or sing to them?', 'clinical': false},
        {'id': 'par1_q3', 'q': 'Does your baby seem to recognize your voice vs a stranger\'s?', 'clinical': false},
        {'id': 'par1_q4', 'q': 'Does your baby make sounds like coos, gurgles, or babbling?', 'clinical': false},
        {'id': 'par1_q5', 'q': 'Does your baby look toward the source of sounds like a rattle?', 'clinical': false},
        {'id': 'par1_q6', 'q': 'Does your baby react differently to loud and soft sounds?', 'clinical': false},
        {'id': 'par1_q7', 'q': 'Was your baby born before 37 weeks (premature)?', 'clinical': true},
        {'id': 'par1_q8', 'q': 'Does your family have a history of hearing problems?', 'clinical': true},
      ],
      2: [
        {'id': 'par2_q1', 'q': 'Does your baby turn to look at you when you call their name?', 'clinical': false},
        {'id': 'par2_q2', 'q': 'Does your baby understand simple words like "No" or their name?', 'clinical': false},
        {'id': 'par2_q3', 'q': 'Does your baby babble with different sounds strung together?', 'clinical': false},
        {'id': 'par2_q4', 'q': 'Does your baby wave bye-bye or point at things they want?', 'clinical': false},
        {'id': 'par2_q5', 'q': 'Does your baby try to copy sounds you make?', 'clinical': false},
        {'id': 'par2_q6', 'q': 'Has your baby started saying any words like mama or dada?', 'clinical': false},
        {'id': 'par2_q7', 'q': 'Does your baby only notice you when they can see you, not when called?', 'clinical': true},
        {'id': 'par2_q8', 'q': 'Has your doctor mentioned ear fluid or ear infections?', 'clinical': true},
      ],
      3: [
        {'id': 'par3_q1', 'q': 'Can your child point to their nose or tummy when you ask?', 'clinical': false},
        {'id': 'par3_q2', 'q': 'Can your child follow a simple instruction without you pointing?', 'clinical': false},
        {'id': 'par3_q3', 'q': 'Does your child enjoy songs, nursery rhymes, or being read to?', 'clinical': false},
        {'id': 'par3_q4', 'q': 'Is your child using more new words every month?', 'clinical': false},
        {'id': 'par3_q5', 'q': 'Does your child try to put two words together like "more juice"?', 'clinical': false},
        {'id': 'par3_q6', 'q': 'Does your child look at you or TV when they hear familiar sounds?', 'clinical': false},
        {'id': 'par3_q7', 'q': 'Do you repeat things several times for your child to respond?', 'clinical': true},
        {'id': 'par3_q8', 'q': 'Does your child pull at their ears frequently?', 'clinical': true},
      ],
      4: [
        {'id': 'par4_q1', 'q': 'Does your child respond when you call from a different room?', 'clinical': false},
        {'id': 'par4_q2', 'q': 'Can your child follow instructions with two or three steps?', 'clinical': false},
        {'id': 'par4_q3', 'q': 'Can your child tell simple stories or talk about their day?', 'clinical': false},
        {'id': 'par4_q4', 'q': 'Do people outside your family understand most of what your child says?', 'clinical': false},
        {'id': 'par4_q5', 'q': 'Does your child enjoy conversation and ask lots of questions?', 'clinical': false},
        {'id': 'par4_q6', 'q': 'Does your child understand colors, shapes, and family member names?', 'clinical': false},
        {'id': 'par4_q7', 'q': 'Does your child set the TV very loud, louder than others prefer?', 'clinical': true},
        {'id': 'par4_q8', 'q': 'Does your child frequently say "what" or "huh"?', 'clinical': true},
      ],
      5: [
        {'id': 'par5_q1', 'q': 'Does your child frequently ask you to repeat things?', 'clinical': false},
        {'id': 'par5_q2', 'q': 'Does your child struggle with schoolwork or following teacher instructions?', 'clinical': false},
        {'id': 'par5_q3', 'q': 'Is your child\'s speech hard to understand or do they mispronounce words?', 'clinical': false},
        {'id': 'par5_q4', 'q': 'Does your child zone out, especially in noisy environments?', 'clinical': false},
        {'id': 'par5_q5', 'q': 'Does your child find it hard to follow conversations with background noise?', 'clinical': false},
        {'id': 'par5_q6', 'q': 'Does your child complain of ringing sounds or ear pain?', 'clinical': false},
        {'id': 'par5_q7', 'q': 'Does your child turn one ear toward you when listening?', 'clinical': false},
        {'id': 'par5_q8', 'q': 'Has your child had more than 3 ear infections in the past 12 months?', 'clinical': true},
      ],
    };
    _questions = parentQs[bracket] ?? parentQs[1]!;
  }

  void _selectChild(ChildModel child) {
    _selectedChild = child;
    _loadQuestions(child.ageBracket);
    setState(() => _step = 1);
  }

  void _answer(String val) {
    _answers.add(ScreeningAnswer(
      questionId: _questions[_qIndex]['id'],
      questionText: _questions[_qIndex]['q'],
      answer: val,
    ));
    if (_qIndex < _questions.length - 1) {
      setState(() => _qIndex++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() { _step = 2; });
    await Future.delayed(const Duration(seconds: 2));

    int pts = 0;
    for (final a in _answers) {
      if (a.answer == 'no') pts += 3;
      if (a.answer == 'sometimes') pts += 1;
    }
    final score = (pts / (_questions.length * 3) * 100).clamp(0, 100).round();
    _riskLevel = score >= 67 ? 'high' : (score >= 34 ? 'medium' : 'low');

    try {
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;
      final sid = fs.generateId('screenings');

      final screening = ScreeningModel(
        screeningId: sid,
        conductedBy: uid,
        conductorRole: 'parent',
        date: DateTime.now(),
        ageBracket: _selectedChild!.ageBracket,
        answers: _answers,
        riskScore: score,
        riskLevel: _riskLevel,
      );
      await fs.addScreening(_selectedChild!.childId, screening);
      await fs.updateChild(_selectedChild!.childId, {
        'lastScreeningDate': Timestamp.now(),
        'riskScore': score,
        'riskLevel': _riskLevel,
        'lastUpdatedAt': Timestamp.now(),
      });
    } catch (e) {
      // Continue to show result even if save fails
    }

    setState(() { _step = 3; });
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
        title: Text(
          _step == 0 ? 'Select Child' : _step == 1 ? 'Home Screening' : _step == 2 ? 'Processing...' : 'Results',
          style: HearTechTextStyles.sectionHeader(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0: return _buildChildSelect();
      case 1: return _buildQuestion();
      case 2: return _buildProcessing();
      case 3: return _buildResult();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildChildSelect() {
    final childrenAsync = ref.watch(parentChildrenProvider);
    return childrenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (children) {
        if (children.isEmpty) {
          return Center(child: Text('No children linked.', style: HearTechTextStyles.subtitle()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: children.length,
          separatorBuilder: (_, i) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final c = children[i];
            return GestureDetector(
              onTap: () => _selectChild(c),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HearTechColors.white,
                  borderRadius: HearTechDecorations.cardBorderRadius,
                  boxShadow: HearTechDecorations.cardShadow,
                ),
                child: Row(children: [
                  AvatarCircle(name: c.name, photoUrl: c.profilePhotoUrl, radius: 28),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: HearTechTextStyles.subtitle()),
                      Text(c.ageString, style: HearTechTextStyles.caption()),
                    ],
                  )),
                  const Icon(Icons.chevron_right, color: HearTechColors.deepTeal),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_qIndex];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        ScreeningProgressBar(current: _qIndex + 1, total: _questions.length),
        const SizedBox(height: 12),
        Text('Question ${_qIndex + 1} of ${_questions.length}', style: HearTechTextStyles.caption()),
        if (q['clinical'] == true) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
          child: Center(
            child: Text(q['q'] as String, style: HearTechTextStyles.screenTitle(), textAlign: TextAlign.center)
                .animate().fadeIn(duration: 200.ms),
          ),
        ),
        // 4 response cards per prompt: Yes | Sometimes | No | I'm not sure
        _Resp(label: 'Yes', color: HearTechColors.green, icon: Icons.check_circle_outline,
            onTap: () => _answer('yes')),
        const SizedBox(height: 10),
        _Resp(label: 'Sometimes', color: HearTechColors.warmOrange, icon: Icons.change_history,
            onTap: () => _answer('sometimes')),
        const SizedBox(height: 10),
        _Resp(label: 'No', color: HearTechColors.coralRed, icon: Icons.cancel_outlined,
            onTap: () => _answer('no')),
        const SizedBox(height: 10),
        _Resp(label: "I'm not sure", color: HearTechColors.textSecondary, icon: Icons.help_outline,
            onTap: () => _answer('not_sure')),
        const SizedBox(height: 16),
        if (_qIndex > 0)
          TextButton.icon(
            onPressed: () { _answers.removeLast(); setState(() => _qIndex--); },
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Previous'),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: HearTechColors.deepTeal.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.hearing, size: 64, color: HearTechColors.deepTeal),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
             .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
        const SizedBox(height: 24),
        Text('Analysing...', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: HearTechColors.deepTeal),
      ]),
    );
  }

  Widget _buildResult() {
    // Plain-language interpretation only — no clinical numbers for parent
    final Color bannerColor;
    final String heading;
    final String message;
    final IconData icon;

    switch (_riskLevel) {
      case 'low':
        bannerColor = HearTechColors.green;
        heading = 'No concerns detected';
        message = 'Keep doing great! Your child\'s responses suggest healthy hearing development.';
        icon = Icons.check_circle;
        break;
      case 'medium':
        bannerColor = HearTechColors.warmOrange;
        heading = 'Some patterns noted';
        message = 'Consider scheduling a check-up with a healthcare professional for further assessment.';
        icon = Icons.info_outline;
        break;
      default:
        bannerColor = HearTechColors.coralRed;
        heading = 'We recommend seeing a professional';
        message = 'We recommend seeing a healthcare professional soon. Your HCW has been notified of these results.';
        icon = Icons.warning_amber;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 24),
        // Color-coded banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.1),
            borderRadius: HearTechDecorations.cardBorderRadius,
            border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            Icon(icon, size: 56, color: bannerColor),
            const SizedBox(height: 16),
            Text(heading, style: HearTechTextStyles.screenTitle(color: bannerColor), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                textAlign: TextAlign.center),
          ]),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
        const SizedBox(height: 24),

        if (_selectedChild != null)
          Text('Screening for: ${_selectedChild!.name}',
              style: HearTechTextStyles.subtitle(), textAlign: TextAlign.center),
        const SizedBox(height: 32),

        HearTechButton(label: 'Back to Dashboard', onPressed: () => context.go(Routes.parentDashboard)),
        const SizedBox(height: 24),
        const DisclaimerFooter(),
      ]),
    );
  }
}

class _Resp extends StatelessWidget {
  final String label; final Color color; final IconData icon; final VoidCallback onTap;
  const _Resp({required this.label, required this.color, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: HearTechDecorations.cardBorderRadius,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Text(label, style: HearTechTextStyles.subtitle(color: color).copyWith(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
