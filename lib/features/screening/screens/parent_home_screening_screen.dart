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
            'clinical': q['isClinical'],
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e'), backgroundColor: HearTechColors.coralRed));
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

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      
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
        ageBracket: _selectedChild!.ageBracket,
        conductorRole: 'parent',
        childId: _selectedChild!.childId,
      );
      
      if (mounted) {
        setState(() {
          _riskLevel = response['riskLevel'] as String;
          _step = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scoring error: $e'), backgroundColor: HearTechColors.coralRed));
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
          _step == 0 ? 'Select Child' : _step == 1 ? 'Home Screening' : _step == 2 ? 'Processing...' : 'Results',
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
