import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart';
import 'package:heartech/shared/widgets/heartech_logo.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/screening_progress_bar.dart';
import 'package:heartech/shared/widgets/risk_gauge.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/disclaimer_footer.dart';
import 'package:heartech/services/fastapi_service.dart';

/// HCW follow-up screening for an existing child — questionnaire + clinical note only.
class HcwFollowUpScreeningScreen extends ConsumerStatefulWidget {
  final String childId;

  const HcwFollowUpScreeningScreen({super.key, required this.childId});

  @override
  ConsumerState<HcwFollowUpScreeningScreen> createState() =>
      _HcwFollowUpScreeningScreenState();
}

class _HcwFollowUpScreeningScreenState
    extends ConsumerState<HcwFollowUpScreeningScreen> {
  // 0=loading, 1=questionnaire, 2=clinical note, 3=processing, 4=result
  int _step = 0;
  int _questionIndex = 0;
  bool _isLoading = false;

  ChildModel? _child;
  final List<ScreeningAnswer> _answers = [];
  String? _selectedAnswer;
  final _noteCtrl = TextEditingController();

  double _sessionRiskScore = 0;
  String _sessionRiskLevel = 'low';
  double _milestoneRiskScore = 0;
  String _milestoneRiskLevel = 'low';

  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadChildAndQuestions();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChildAndQuestions() async {
    setState(() => _isLoading = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final child = await fs.getChild(widget.childId);
      if (child == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Child not found.')),
          );
          context.go(Routes.hcwDashboard);
        }
        return;
      }

      final fastApi = ref.read(fastApiServiceProvider);
      final res = await fastApi.getQuestionnaire(
        role: 'hcw',
        bracketId: child.ageBracket,
      );
      final fetched = List<Map<String, dynamic>>.from(res['questions'] ?? []);

      if (mounted) {
        setState(() {
          _child = child;
          _questions = fetched.map((q) => {
                'id': q['id'],
                'q': q['text'],
                'clinical': q['isClinical'] ?? false,
              }).toList();
          _step = _questions.isEmpty ? 0 : 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: ${FastApiService.userFacingMessage(e)}'),
              backgroundColor: HearTechColors.coralRed),
        );
        context.go(Routes.hcwChildProfile.replaceFirst(':childId', widget.childId));
      }
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
      setState(() => _step = 2);
    }
  }

  void _goBackQuestion() {
    if (_questionIndex > 0) {
      _answers.removeLast();
      setState(() {
        _questionIndex--;
        _selectedAnswer = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_child == null) return;
    setState(() => _step = 3);

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;

      final apiAnswers = _answers.map((a) {
        final qMatched = _questions.firstWhere(
          (q) => q['id'] == a.questionId,
          orElse: () => {'clinical': false},
        );
        return {
          'questionId': a.questionId,
          'answer': a.answer,
          'isClinical': qMatched['clinical'],
        };
      }).toList();

      final sessionResponse = await fastApi.calculateRiskScore(
        answers: apiAnswers,
        ageBracket: _child!.ageBracket,
        conductorRole: 'hcw',
        childId: _child!.childId,
        clinicalNote: _noteCtrl.text.trim(),
        childMetadata: {
          'medicalHistory': _child!.medicalHistory.toJson(),
        },
      );

      _sessionRiskScore = (sessionResponse['riskScore'] as num).toDouble();
      _sessionRiskLevel = sessionResponse['riskLevel'] as String;

      final screeningId =
          fs.generateId(FirestorePaths.screenings(_child!.childId));
      final screening = ScreeningModel(
        screeningId: screeningId,
        conductedBy: uid,
        conductorRole: 'hcw',
        date: DateTime.now(),
        ageBracket: _child!.ageBracket,
        answers: _answers,
        riskScore: _sessionRiskScore.round(),
        riskLevel: _sessionRiskLevel,
        clinicalNote: _noteCtrl.text.trim(),
      );
      await fs.addScreening(_child!.childId, screening);

      final aggregate = await fastApi.aggregateRiskScore(
        childId: _child!.childId,
        trigger: 'hcw_screening',
      );

      _milestoneRiskScore = (aggregate['riskScore'] as num).toDouble();
      _milestoneRiskLevel = aggregate['riskLevel'] as String;

      await fs.updateChild(_child!.childId, {
        'lastScreeningDate': DateTime.now(),
        'riskScore': _milestoneRiskScore.round(),
        'riskLevel': _milestoneRiskLevel,
        'lastUpdatedAt': DateTime.now(),
        if (aggregate['breakdown'] != null)
          'riskBreakdown': aggregate['breakdown'],
      });

      if (mounted) setState(() => _step = 4);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'),
              backgroundColor: HearTechColors.coralRed),
        );
        setState(() => _step = 2);
      }
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Screening?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go(
                  Routes.hcwChildProfile.replaceFirst(':childId', widget.childId));
            },
            child: const Text('Exit',
                style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
  }

  String _stepTitle() {
    switch (_step) {
      case 1:
        return 'Follow-up Screening';
      case 2:
        return 'Clinical Note';
      case 3:
        return 'Processing...';
      case 4:
        return 'Result';
      default:
        return 'Follow-up Screening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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

  Widget _body() {
    if (_isLoading || _step == 0) {
      return const Center(
          child: CircularProgressIndicator(color: HearTechColors.deepTeal));
    }
    switch (_step) {
      case 1:
        return _buildQuestionnaire();
      case 2:
        return _buildClinicalNote();
      case 3:
        return _buildProcessing();
      case 4:
        return _buildResult();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChildHeader() {
    final child = _child!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: HearTechDecorations.cardBorderRadius,
        boxShadow: HearTechDecorations.subtleShadow,
      ),
      child: Row(
        children: [
          AvatarCircle(name: child.name, photoUrl: child.profilePhotoUrl, radius: 24),
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
        ],
      ),
    );
  }

  Widget _buildQuestionnaire() {
    final q = _questions[_questionIndex];
    final isClinical = q['clinical'] as bool;
    final isLast = _questionIndex == _questions.length - 1;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildChildHeader(),
          ScreeningProgressBar(
              current: _questionIndex + 1, total: _questions.length),
          const SizedBox(height: 8),
          Text('Question ${_questionIndex + 1} of ${_questions.length}',
              style: HearTechTextStyles.caption()),
          if (isClinical) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HearTechColors.coralRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Clinical',
                  style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(q['q'] as String,
                      style: HearTechTextStyles.screenTitle(),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  _RespCard(
                      label: 'Yes',
                      color: HearTechColors.green,
                      icon: Icons.check_circle_outline,
                      selected: _selectedAnswer == 'yes',
                      onTap: () => setState(() => _selectedAnswer = 'yes')),
                  const SizedBox(height: 10),
                  _RespCard(
                      label: 'Partial',
                      color: HearTechColors.warmOrange,
                      icon: Icons.change_history,
                      selected: _selectedAnswer == 'partial',
                      onTap: () => setState(() => _selectedAnswer = 'partial')),
                  const SizedBox(height: 10),
                  _RespCard(
                      label: 'No',
                      color: HearTechColors.coralRed,
                      icon: Icons.cancel_outlined,
                      selected: _selectedAnswer == 'no',
                      onTap: () => setState(() => _selectedAnswer = 'no')),
                  const SizedBox(height: 10),
                  _RespCard(
                      label: 'Not Sure',
                      color: HearTechColors.textSecondary,
                      icon: Icons.help_outline,
                      selected: _selectedAnswer == 'not_sure',
                      onTap: () => setState(() => _selectedAnswer = 'not_sure')),
                ],
              ),
            ),
          ),
          Row(
            children: [
              if (_questionIndex > 0)
                Expanded(
                  child: TextButton.icon(
                    onPressed: _goBackQuestion,
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                  ),
                ),
              if (_questionIndex > 0) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: HearTechButton(
                  label: isLast ? 'Continue to Note' : 'Next',
                  onPressed: _selectedAnswer != null
                      ? () => _answerQuestion(_selectedAnswer!)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalNote() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChildHeader(),
          Text('Clinical Notes', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text(
            'Add observations for this follow-up screening session.',
            style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _noteCtrl,
            maxLines: 8,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Type your clinical notes here...',
              filled: true,
              fillColor: HearTechColors.paleTeal,
              border: OutlineInputBorder(
                  borderRadius: HearTechDecorations.inputBorderRadius,
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          HearTechButton(label: 'Analyse Results', onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HearTechLogo(size: 96)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 800.ms,
              ),
          const SizedBox(height: 24),
          Text('Analysing...', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: HearTechColors.deepTeal),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Follow-up Complete',
              style: HearTechTextStyles.screenTitle(color: HearTechColors.deepTeal)),
          const SizedBox(height: 8),
          Text(
            'Combined milestone score updated from all sources.',
            style: HearTechTextStyles.caption(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          RiskGauge(
              score: _milestoneRiskScore.round(),
              riskLevel: _milestoneRiskLevel,
              size: 160),
          const SizedBox(height: 12),
          RiskBadge(riskLevel: _milestoneRiskLevel, large: true),
          const SizedBox(height: 16),
          Text(
            'This session: ${_sessionRiskLevel.toUpperCase()} (${_sessionRiskScore.round()}%)',
            style: HearTechTextStyles.caption(),
          ),
          const SizedBox(height: 32),
          HearTechButton(
            label: 'Back to Profile',
            onPressed: () => context.go(
                Routes.hcwChildProfile.replaceFirst(':childId', widget.childId)),
          ),
          const SizedBox(height: 12),
          HearTechButton(
            label: 'Clinical Assistant',
            icon: Icons.medical_services_outlined,
            isSecondary: true,
            onPressed: () => context.push(
              Routes.referralChat.replaceFirst(':childId', widget.childId),
            ),
          ),
          const SizedBox(height: 24),
          const DisclaimerFooter(),
        ],
      ),
    );
  }
}

class _RespCard extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RespCard({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

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
              child: Text(label,
                  style: HearTechTextStyles.subtitle(color: color)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: HearTechColors.deepTeal, size: 22),
          ],
        ),
      ),
    );
  }
}
