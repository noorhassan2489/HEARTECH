import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/core/constants/firestore_paths.dart';

/// Parent Home Screening — select child → questionnaire → plain-language result.
/// No clinical numbers visible to parent. Results use spec-exact headings.
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
  int _riskScore = 0;
  String? _screeningId;
  List<Map<String, dynamic>> _questions = [];
  String? _selectedAnswer;

  bool _isLoading = false;

  Future<void> _loadQuestions(int bracket) async {
    setState(() => _isLoading = true);
    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final res = await fastApi.getQuestionnaire(role: 'parent', bracketId: bracket);
      if (mounted) {
        setState(() {
          final fetched = List<Map<String, dynamic>>.from(res['questions'] ?? []);
          _questions = fetched.map((q) => {
            'id': q['id'],
            'q': q['text'],
            'clinical': false, // Parent questions have no clinical markers
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load questions: $e'),
            backgroundColor: HearTechColors.coralRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectChild(ChildModel child) {
    _selectedChild = child;
    _loadQuestions(child.ageBracket);
    setState(() => _step = 1);
  }

  void _answerAndAdvance() {
    if (_selectedAnswer == null) return;

    _answers.add(ScreeningAnswer(
      questionId: _questions[_qIndex]['id'],
      questionText: _questions[_qIndex]['q'],
      answer: _selectedAnswer!,
    ));
    _selectedAnswer = null;

    if (_qIndex < _questions.length - 1) {
      setState(() => _qIndex++);
    } else {
      _submit();
    }
  }

  Future<void> _submit() async {
    setState(() { _step = 2; });

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      final apiAnswers = _answers.map((a) {
        return {
          'questionId': a.questionId,
          'answer': a.answer,
          'isClinical': false,
        };
      }).toList();

      final response = await fastApi.calculateRiskScore(
        answers: apiAnswers,
        ageBracket: _selectedChild!.ageBracket,
        conductorRole: 'parent',
        childId: _selectedChild!.childId,
      );

      _riskLevel = response['riskLevel'] as String;
      _riskScore = response['riskScore'] as int? ?? 0;

      // Write screening to Firestore
      _screeningId = firestoreService.generateId(
          FirestorePaths.screenings(_selectedChild!.childId));
      final screening = ScreeningModel(
        screeningId: _screeningId!,
        conductedBy: ref.read(currentFirebaseUserProvider)?.uid ?? '',
        conductorRole: 'parent',
        date: DateTime.now(),
        ageBracket: _selectedChild!.ageBracket,
        answers: _answers,
        riskScore: _riskScore,
        riskLevel: _riskLevel,
      );
      await firestoreService.addScreening(_selectedChild!.childId, screening);

      // Update child document
      await firestoreService.updateChild(_selectedChild!.childId, {
        'lastScreeningDate': DateTime.now(),
        'riskScore': _riskScore,
        'riskLevel': _riskLevel,
        'lastUpdatedAt': DateTime.now(),
      });

      // Fire HCW-07: Parent home screening submitted → to HCW
      final hcwIds = _selectedChild!.hcwIds;
      if (hcwIds.isNotEmpty) {
        try {
          await fastApi.sendNotification(
            uid: hcwIds[0],
            type: 'HCW-07',
            title: 'Home Screening Completed',
            body: 'A parent completed a home screening for ${_selectedChild!.name}.',
            relatedChildId: _selectedChild!.childId,
          );
        } catch (_) {
          // Non-critical — don't block result
        }
      }

      if (mounted) {
        setState(() { _step = 3; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Scoring error: $e'),
            backgroundColor: HearTechColors.coralRed));
        setState(() { _step = 0; });
      }
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
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text(
          _step == 0 ? 'Select Child' : _step == 1 ? 'Home Screening'
              : _step == 2 ? 'Processing...' : 'Results',
          style: HearTechTextStyles.sectionHeader(),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.child_care, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No children linked yet.', style: HearTechTextStyles.subtitle()),
                const SizedBox(height: 8),
                Text('Claim a profile first.', style: HearTechTextStyles.caption()),
              ],
            ),
          );
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
                  RiskBadge(riskLevel: c.riskLevel),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: HearTechColors.deepTeal),
                ]),
              ),
            ).animate(delay: (i * 60).ms).fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
          },
        );
      },
    );
  }

  Widget _buildQuestion() {
    if (_questions.isEmpty) return const SizedBox.shrink();
    final q = _questions[_qIndex];
    final isLast = _qIndex == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        ScreeningProgressBar(current: _qIndex + 1, total: _questions.length),
        const SizedBox(height: 12),
        Text('Question ${_qIndex + 1} of ${_questions.length}', style: HearTechTextStyles.caption()),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              Text(q['q'] as String, style: HearTechTextStyles.screenTitle(), textAlign: TextAlign.center)
                  .animate().fadeIn(duration: 200.ms),
              const SizedBox(height: 24),
              // 4 response cards: Yes | Sometimes | No | I'm not sure
              _SelectableResp(label: 'Yes', color: HearTechColors.green, icon: Icons.check_circle_outline,
                  selected: _selectedAnswer == 'yes', onTap: () => setState(() => _selectedAnswer = 'yes')),
              const SizedBox(height: 10),
              _SelectableResp(label: 'Sometimes', color: HearTechColors.warmOrange, icon: Icons.change_history,
                  selected: _selectedAnswer == 'sometimes', onTap: () => setState(() => _selectedAnswer = 'sometimes')),
              const SizedBox(height: 10),
              _SelectableResp(label: 'No', color: HearTechColors.coralRed, icon: Icons.cancel_outlined,
                  selected: _selectedAnswer == 'no', onTap: () => setState(() => _selectedAnswer = 'no')),
              const SizedBox(height: 10),
              _SelectableResp(label: "I'm not sure", color: HearTechColors.textSecondary, icon: Icons.help_outline,
                  selected: _selectedAnswer == 'not_sure', onTap: () => setState(() => _selectedAnswer = 'not_sure')),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_qIndex > 0)
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    _answers.removeLast();
                    setState(() { _qIndex--; _selectedAnswer = null; });
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ),
            if (_qIndex > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: HearTechButton(
                label: isLast ? 'Submit' : 'Next',
                onPressed: _selectedAnswer != null ? _answerAndAdvance : null,
              ),
            ),
          ],
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
    // Plain-language only — spec-exact headings and messages
    final Color bannerColor;
    final String heading;
    final String message;
    final IconData icon;

    switch (_riskLevel) {
      case 'low':
        bannerColor = HearTechColors.green;
        heading = 'Things Look Great!';
        message = 'No hearing concerns detected. Keep up the great work!';
        icon = Icons.check_circle;
        break;
      case 'medium':
        bannerColor = HearTechColors.warmOrange;
        heading = 'Some Patterns Noted';
        message = 'We noticed a few things worth discussing. Consider scheduling a check-up with your healthcare provider.';
        icon = Icons.info_outline;
        break;
      default:
        bannerColor = HearTechColors.coralRed;
        heading = 'Professional Advice Recommended';
        message = "We recommend seeing a healthcare professional soon to discuss your child's hearing development.";
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
            Text(heading, style: HearTechTextStyles.screenTitle(color: bannerColor),
                textAlign: TextAlign.center),
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

        HearTechButton(label: 'Done', onPressed: () => context.go(Routes.parentDashboard)),
        const SizedBox(height: 24),
        const DisclaimerFooter(),
      ]),
    );
  }
}

class _SelectableResp extends StatelessWidget {
  final String label; final Color color; final IconData icon;
  final bool selected; final VoidCallback onTap;
  const _SelectableResp({required this.label, required this.color, required this.icon,
      required this.selected, required this.onTap});
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
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: HearTechTextStyles.subtitle(color: color)
              .copyWith(fontWeight: FontWeight.w700))),
          if (selected)
            const Icon(Icons.check_circle, color: HearTechColors.deepTeal, size: 22),
        ]),
      ),
    );
  }
}
