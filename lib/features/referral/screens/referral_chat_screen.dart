import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/navigation_utils.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/app_constants.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/referral_model.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';

/// Referral chat screen — HCW instructs AI to generate referral letters.
class ReferralChatScreen extends ConsumerStatefulWidget {
  final String childId;
  const ReferralChatScreen({super.key, required this.childId});
  @override
  ConsumerState<ReferralChatScreen> createState() => _ReferralChatScreenState();
}

class _ReferralChatScreenState extends ConsumerState<ReferralChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  ChildModel? _child;
  bool _isLoadingChild = true;
  bool _isAiLoading = false;
  bool _isGeneratingReferral = false;
  int? _exportingPdfIndex;
  int? _exportingDocxIndex;

  // Chat messages: {role, text, isLoading, referralText?, referralId?}
  final List<Map<String, dynamic>> _messages = [];
  String? _activeDraftReferralId;

  static const _suggestionChips = [
    'Suggest investigations',
    'Make it urgent',
    'Add speech therapy',
    'Include ear infection history',
    'Recommend ABR test',
    'Add precautions for parent',
    'Include family history',
    'Recommend genetic counselling',
  ];
  static const int _maxSessionContextTurns = 4;

  @override
  void initState() {
    super.initState();
    _loadChild();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Load child and show first AI message ───────────────────────────────
  Future<void> _loadChild() async {
    try {
      final fs = ref.read(firestoreServiceProvider);
      _child = await fs.getChild(widget.childId);
      if (_child != null && mounted) {
        final level = _child!.riskLevel.toUpperCase();
        final score = _child!.riskScore;
        final age = _child!.ageString;
        setState(() {
          _isLoadingChild = false;
          _messages.add({
            'role': 'ai',
            'text':
                'I have loaded ${_child!.name}\'s profile.\n'
                'Risk Level: $level | Score: $score/100 | Age: $age\n\n'
                'Ask clinical questions or request a referral letter. '
                'Tap a suggestion below to get started.',
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingChild = false;
          _messages.add({
            'role': 'ai',
            'text': 'Failed to load child profile: $e',
          });
        });
      }
    }
  }

  // ── Send message ───────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isAiLoading || _child == null) return;

    final rawInstruction = text.trim();
    if (_isNewReferralRequest(rawInstruction.toLowerCase())) {
      _activeDraftReferralId = null;
    }
    final expandedInstruction = _expandSuggestionInstruction(rawInstruction);
    final instruction = _resolveInstructionWithContext(
      rawInstruction: rawInstruction,
      payloadInstruction: expandedInstruction,
    );
    _inputController.clear();

    setState(() {
      // Show only what HCW typed; keep any context augmentation internal.
      _messages.add({'role': 'hcw', 'text': rawInstruction});
      _isGeneratingReferral = true;
      _isAiLoading = true;
    });
    _scrollToBottom();

    try {
      final api = ref.read(fastApiServiceProvider);
      debugPrint('[CHAT] 1. Got API service');

      final user = await ref
          .read(firestoreServiceProvider)
          .getUser(ref.read(firebaseAuthServiceProvider).uid!);
      debugPrint('[CHAT] 2. Got user: ${user?.name}');

      // Build flags list from medical history
      final flags = <String>[];
      if (_child!.medicalHistory.prematureBirth) flags.add('Premature birth');
      if (_child!.medicalHistory.nicuAdmission) flags.add('NICU admission');
      if (_child!.medicalHistory.familyHistoryHearingLoss) {
        flags.add('Family history of hearing loss');
      }
      if (_child!.medicalHistory.earInfectionCount > 0) {
        flags.add(
          '${_child!.medicalHistory.earInfectionCount} ear infection(s)',
        );
      }

      final bracketLabel =
          AppConstants.ageBracketLabels[_child!.ageBracket] ?? '';
      debugPrint('[CHAT] 3. Sending request...');

      final result = await api.generateReferralChat(
        childData: {
          'childId': widget.childId,
          'name': _child!.name,
          'age': _child!.ageString,
          'gender': _child!.gender,
          'dob': '${_child!.dob.day}/${_child!.dob.month}/${_child!.dob.year}',
          'riskScore': _child!.riskScore,
          'riskLevel': _child!.riskLevel,
          'ageBracket': bracketLabel,
          'flags': flags,
          'hcwName': user?.name ?? '',
          'hcwTitle': user?.title ?? '',
          'hcwSpec': user?.specialization ?? '',
          'hcwHospital': user?.hospitalName ?? '',
        },
        hcwInstruction: instruction,
      );

      debugPrint('[CHAT] 4. Got result: ${result.keys.toList()}');
      debugPrint(
        '[CHAT] 5. referralText length: ${(result['referralText'] as String?)?.length}',
      );

      if (!mounted) return;

      final responseText =
          result['referralText'] as String? ?? 'No response received.';
      final success = result['success'] as bool? ?? false;
      final intent = (result['intent'] as String? ?? '').trim();
      final needsClarification = result['needsClarification'] as bool? ?? false;
      _applyAiResponse(
        responseText: responseText,
        success: success,
        intent: intent,
        needsClarification: needsClarification,
      );
    } catch (e, stack) {
      debugPrint('[CHAT] ERROR: $e');
      debugPrint('[CHAT] STACK: $stack');
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'ai',
            'text': 'Error generating referral: $e',
          });
        });
        _scrollToBottom();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReferral = false;
          _isAiLoading = false;
        });
        debugPrint(
          '[CHAT] 6. Done — messages=${_messages.length}, '
          'generating=$_isGeneratingReferral',
        );
      }
    }
  }

  bool _isNewReferralRequest(String lower) {
    return lower.contains('generate referral') ||
        lower.contains('create referral') ||
        lower.contains('make referral') ||
        lower.contains('write referral') ||
        lower.contains('produce referral');
  }

  bool _looksLikeReferToUpdate(String lower) {
    return RegExp(r'\brefer(?:ral)?\s+to\b').hasMatch(lower) ||
        RegExp(r'\brefer(?:ral)?\s+(?:this|it|the)\s+to\b').hasMatch(lower) ||
        RegExp(r'\bsend\s+(?:this|it|the)\s+to\b').hasMatch(lower) ||
        RegExp(r'\badd\s+refer(?:ral)?\s+to\b').hasMatch(lower) ||
        RegExp(r'\binclude\s+refer\s+to\b').hasMatch(lower) ||
        (lower.contains('sorry') && lower.contains('refer'));
  }

  bool _mentionsReferralDocument(String lower) {
    return lower.contains('referral') ||
        lower.contains('refferal') ||
        lower.contains('referal') ||
        lower.contains('the letter');
  }

  bool _looksLikeMedicineSectionEdit(String lower) {
    return RegExp(
          r'\b(?:add|include|put|insert|remove)\b.+\b(?:medicine|medicines|medication|meds)\b',
        ).hasMatch(lower) ||
        RegExp(
          r'\b(?:medicine|medicines|medication|meds)\b.+\b(?:add|include|remove)\b',
        ).hasMatch(lower);
  }

  bool _looksLikeImperativeReferralEdit(String lower) {
    return lower.startsWith('add ') ||
        lower.startsWith('include ') ||
        lower.startsWith('remove ') ||
        lower.startsWith('update ') ||
        lower.startsWith('edit ') ||
        lower.startsWith('change ') ||
        lower.startsWith('also ') ||
        lower.startsWith('put ') ||
        lower.startsWith('insert ');
  }

  bool _looksLikeReferralEdit(String lower) {
    final patterns = [
      r'\b(?:add|include|edit|update|change|modify|remove)\b.*\brefer(?:r?al|ral|al)\b',
      r'\brefer(?:r?al|ral|al)\b.*\b(?:add|include|edit|update|change|modify)\b',
      r'\bin (?:the|this) refer(?:r?al|ral|al)\b',
      r'\bmake it urgent\b',
      r'\badd (?:more )?(?:medicine|medication|meds)\b',
      r'\bsuggest investigations?\b',
      r'\badd speech\b',
      r'\badd that\b',
      r'\balso (?:have|has)\b',
      r'\b(?:add|include) precaution\b',
    ];
    return patterns.any((pattern) => RegExp(pattern).hasMatch(lower));
  }

  bool _isPureClinicalQuestion(String lower) {
    if (_mentionsReferralDocument(lower) ||
        _looksLikeMedicineSectionEdit(lower) ||
        _looksLikeImperativeReferralEdit(lower)) {
      return false;
    }
    return (lower.startsWith('what ') ||
            lower.startsWith('could ') ||
            lower.startsWith('can ') ||
            lower.startsWith('why ') ||
            lower.startsWith('how ') ||
            lower.startsWith('when ') ||
            lower.startsWith('where ') ||
            lower.startsWith('who ') ||
            lower.startsWith('is ') ||
            lower.startsWith('does ') ||
            lower.startsWith('should ')) &&
        !lower.contains('referral');
  }

  bool _shouldAttachPriorReferral(String lower) {
    if (_lastReferralLetter() == null) return false;
    if (_isNewReferralRequest(lower)) return false;
    if (_isPureClinicalQuestion(lower)) return false;
    return _looksLikeReferToUpdate(lower) ||
        _looksLikeReferralEdit(lower) ||
        _looksLikeMedicineSectionEdit(lower) ||
        _looksLikeImperativeReferralEdit(lower) ||
        (_mentionsReferralDocument(lower) &&
            (lower.contains('add') ||
                lower.contains('include') ||
                lower.contains('edit') ||
                lower.contains('update') ||
                lower.contains('change') ||
                lower.contains('remove')));
  }

  String? _lastReferralLetter() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (msg['referralText'] is String) {
        final txt = (msg['referralText'] as String).trim();
        if (txt.isNotEmpty) return txt;
      }
    }
    return null;
  }

  String _buildReferralEditContext(String instruction) {
    final prior = _lastReferralLetter();
    if (prior == null) return instruction;
    return '$instruction\n\nConversation context:\nImmediate prior referral letter:\n$prior';
  }

  bool _wantsFullSessionContext(String lower) {
    return lower.contains('all of this') ||
        lower.contains('all of these') ||
        lower.contains('everything discussed') ||
        lower.contains('everything above') ||
        lower.contains('everything we');
  }

  bool _needsImmediateContext(String lower) {
    final asksAboutThis =
        lower.contains(' for this') ||
        lower.contains(' for that') ||
        lower.contains(' for it') ||
        lower.contains('medicine for this') ||
        lower.contains('any medicine for this') ||
        (lower.contains('medicine') && lower.contains('this')) ||
        (lower.contains('precaution') && lower.contains('this'));
    final clarifies =
        lower.startsWith('no ') ||
        lower.startsWith('no i mean') ||
        lower.contains("that's not") ||
        lower.contains('not what i said') ||
        lower.startsWith('bro ');
    return asksAboutThis || clarifies;
  }

  bool _isMeaningFollowUp(String lower) {
    final meaningPattern = RegExp(r'\bwhat does\b.*\bmean(s)?\b');
    return meaningPattern.hasMatch(lower) ||
        lower.startsWith('can you explain') ||
        lower.startsWith('please explain');
  }

  bool _needsFollowUpContext(String lower) {
    return _isMeaningFollowUp(lower) ||
        lower.contains('what do they mean') ||
        lower.contains('what could these') ||
        lower.contains('what do these mean') ||
        lower.contains('what does that mean') ||
        lower.contains('could the child') ||
        (lower.contains('could ') && lower.contains(' have ')) ||
        lower.contains('for relief') ||
        lower.contains('proper medicine') ||
        lower.contains('can this') ||
        lower.contains('is this') ||
        lower.startsWith('okay could') ||
        lower.startsWith('okay so') ||
        lower.startsWith('so ') ||
        lower.startsWith('then ') ||
        lower.contains('any test') ||
        lower.contains("test's") ||
        lower.contains('tests or') ||
        lower.contains('test or') ||
        (lower.contains('medication') && lower.contains(' or '));
  }

  bool _isReusableAiTurn(Map<String, dynamic> msg) {
    final role = msg['role'];
    final status = (msg['status'] as String? ?? '').toLowerCase();
    final success = msg['success'] == true;
    final needsClarification = msg['needsClarification'] == true;
    if (role != 'ai' || !success || needsClarification) return false;
    if (status == 'error' || status == 'clarify') return false;
    return status == 'answer' || status == 'referral';
  }

  bool _isLowValueAnswer(String text) {
    final lower = text.toLowerCase();
    final markers = [
      "i couldn't produce a reliable clinical answer",
      "could you rephrase with the child's key symptoms",
      'based on the current question, perform focused otoscopy',
      'arrange ent/audiology review if concerns persist',
    ];
    return markers.any(lower.contains);
  }

  ({String? question, String? answer}) _lastExchangeBefore(String instruction) {
    final exclude = instruction.toLowerCase();
    String? lastQuestion;
    String? lastAnswer;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final msg = _messages[i];
      if (lastAnswer == null &&
          _isReusableAiTurn(msg) &&
          msg['answerText'] is String &&
          (msg['status'] as String? ?? '').toLowerCase() == 'answer') {
        final txt = (msg['answerText'] as String).trim();
        if (txt.isNotEmpty && !_isLowValueAnswer(txt)) {
          lastAnswer = txt;
        }
      }
      if (lastQuestion == null &&
          msg['role'] == 'hcw' &&
          msg['text'] is String) {
        final txt = (msg['text'] as String).trim();
        if (txt.isNotEmpty && txt.toLowerCase() != exclude) {
          lastQuestion = txt;
        }
      }
      if (lastQuestion != null && lastAnswer != null) break;
    }
    return (question: lastQuestion, answer: lastAnswer);
  }

  String _compactContextText(String input) {
    final singleLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 220) return singleLine;
    return '${singleLine.substring(0, 220)}...';
  }

  String _buildImmediateContext(String instruction) {
    final last = _lastExchangeBefore(instruction);
    if (last.question == null && last.answer == null) return instruction;
    final parts = <String>[
      if (last.question != null)
        'Immediate prior HCW question: ${last.question}',
      if (last.answer != null)
        'Immediate prior AI answer: ${_compactContextText(last.answer!)}',
    ];
    return '$instruction\n\nConversation context:\n${parts.join('\n')}';
  }

  List<String> _priorHcwQuestions({required String excludeInstruction}) {
    final exclude = excludeInstruction.toLowerCase();
    final questions = <String>[];
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg['role'] == 'hcw' && msg['text'] is String) {
        final txt = (msg['text'] as String).trim();
        if (txt.isEmpty || txt.toLowerCase() == exclude) continue;
        var hasReusableAi = false;
        for (var j = i + 1; j < _messages.length; j++) {
          final next = _messages[j];
          if (next['role'] == 'hcw') break;
          if (_isReusableAiTurn(next)) {
            hasReusableAi = true;
            break;
          }
        }
        if (hasReusableAi) {
          questions.add(txt);
        }
      }
    }
    if (questions.length <= _maxSessionContextTurns) {
      return questions;
    }
    return questions.sublist(questions.length - _maxSessionContextTurns);
  }

  String _resolveInstructionWithContext({
    required String rawInstruction,
    required String payloadInstruction,
  }) {
    final lower = rawInstruction.toLowerCase();
    final priorQuestions = _priorHcwQuestions(excludeInstruction: rawInstruction);

    if (_shouldAttachPriorReferral(lower)) {
      return _buildReferralEditContext(payloadInstruction);
    }

    if (_needsImmediateContext(lower)) {
      return _buildImmediateContext(payloadInstruction);
    }

    if (_wantsFullSessionContext(lower)) {
      if (priorQuestions.isEmpty) return payloadInstruction;
      final session = priorQuestions.map((q) => '- $q').join('\n');
      return '$payloadInstruction\n\nConversation context:\nPrior HCW questions in this session:\n$session';
    }

    if (!_needsFollowUpContext(lower)) return payloadInstruction;
    // Follow-up context: attach only the immediate prior exchange.
    return _buildImmediateContext(payloadInstruction);
  }

  String _expandSuggestionInstruction(String instruction) {
    final lower = instruction.toLowerCase();
    switch (lower) {
      case 'suggest investigations':
        return '$instruction for this child based on documented profile and screening findings.';
      case 'make it urgent':
        return '$instruction for this child if clinically indicated, with brief reasoning.';
      case 'add speech therapy':
        return '$instruction in the care plan only when clinically indicated.';
      case 'include ear infection history':
        return '$instruction for this child where relevant to the current clinical question.';
      case 'recommend abr test':
        return '$instruction for this child only if clinically appropriate for age and findings.';
      case 'add precautions for parent':
        return '$instruction for this child with concise safety-focused advice.';
      case 'include family history':
        return '$instruction where relevant to this child and current concern.';
      case 'recommend genetic counselling':
        return '$instruction only if supported by the child profile and red flags.';
      default:
        return instruction;
    }
  }

  String _referralBubblePreview(String full) {
    final trimmed = full.trim();
    if (trimmed.isEmpty) {
      return 'Referral draft is ready. Open the letter to review the full document.';
    }
    if (trimmed.length <= 360) return trimmed;
    final cut = trimmed.substring(0, 360);
    final lastBreak = cut.lastIndexOf('\n');
    if (lastBreak > 180) {
      return '${cut.substring(0, lastBreak).trim()}...\n\nOpen the referral letter below for the full document.';
    }
    return '$cut...\n\nOpen the referral letter below for the full document.';
  }

  void _applyAiResponse({
    required String responseText,
    required bool success,
    required String intent,
    required bool needsClarification,
  }) {
    final normalizedIntent = intent.toLowerCase().trim();
    final clarificationFallbackText =
        responseText.toLowerCase().contains(
          "i couldn't produce a reliable clinical answer",
        ) ||
        responseText.toLowerCase().contains(
          "could you rephrase with the child's key symptoms",
        ) ||
        responseText.toLowerCase().contains('the hcw is asking') ||
        responseText.toLowerCase().contains('at most 10 brief sentences') ||
        responseText.toLowerCase().contains('mode: clinical') ||
        responseText.toLowerCase().contains('child profile:');
    final effectiveNeedsClarification =
        needsClarification || clarificationFallbackText;
    final status = !success || normalizedIntent == 'error'
        ? 'error'
        : effectiveNeedsClarification || normalizedIntent == 'clarify'
        ? 'clarify'
        : normalizedIntent == 'referral'
        ? 'referral'
        : 'answer';
    final isReferral = status == 'referral';
    final bubbleText = switch (status) {
      'error' => responseText.trim().isNotEmpty
          ? responseText
          : 'Request failed — please try again.',
      'clarify' => responseText,
      'referral' => _referralBubblePreview(responseText),
      _ => responseText,
    };

    setState(() {
      final payload = <String, dynamic>{
        'role': 'ai',
        'text': bubbleText,
        'answerText': responseText,
        'intent': normalizedIntent,
        'status': status,
        'needsClarification': effectiveNeedsClarification,
        'success': success,
      };
      if (isReferral) {
        payload['referralText'] = responseText;
        if (_activeDraftReferralId != null) {
          payload['referralId'] = _activeDraftReferralId;
        }
      }
      _messages.add(payload);
    });
    _scrollToBottom();

    if (isReferral && success) {
      _persistReferralDraft(responseText);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            'error' => 'Request failed. Check details.',
            'clarify' => 'Additional clinical details required.',
            'referral' => 'Referral draft ready — review the letter below.',
            _ => 'Clinical answer ready.',
          }),
          backgroundColor: status == 'error' || status == 'clarify'
              ? Colors.orange.shade700
              : HearTechColors.green,
        ),
      );
    });
  }

  Future<void> _persistReferralDraft(String letterText) async {
    if (_child == null) return;
    final uid = ref.read(firebaseAuthServiceProvider).uid;
    if (uid == null || uid.isEmpty) return;

    final fs = ref.read(firestoreServiceProvider);
    final title = ReferralModel.titleFromLetter(letterText);

    try {
      if (_activeDraftReferralId != null) {
        await fs.updateReferralDraft(
          widget.childId,
          _activeDraftReferralId!,
          letterText: letterText,
          title: title,
        );
      } else {
        final referralId =
            fs.generateId(FirestorePaths.referrals(widget.childId));
        final referral = ReferralModel(
          referralId: referralId,
          generatedByHcwId: uid,
          generatedAt: DateTime.now(),
          letterText: letterText,
          screeningId: 'assistant',
          status: ReferralStatus.draft,
          title: title,
        );
        await fs.addReferral(widget.childId, referral);
        _activeDraftReferralId = referralId;
      }

      if (!mounted) return;
      setState(() {
        for (var i = _messages.length - 1; i >= 0; i--) {
          final msg = _messages[i];
          if (msg['role'] == 'ai' && msg['referralText'] != null) {
            _messages[i] = {
              ...msg,
              'referralId': _activeDraftReferralId,
            };
            break;
          }
        }
      });
    } catch (e) {
      debugPrint('[CHAT] Failed to persist referral draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save draft to profile: $e')),
        );
      }
    }
  }

  void _openReferralLetterPage(String responseText) {
    if (!mounted) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => _ReferralLetterPage(
          childName: _child?.name ?? 'Patient',
          letterText: responseText,
        ),
      ),
    );
  }

  // ── Export PDF ──────────────────────────────────────────────────────────
  String _referralBodyForMessage(int messageIndex) {
    final msg = _messages[messageIndex];
    return (msg['referralText'] as String?) ?? (msg['text'] as String);
  }

  Future<void> _exportPdf(int messageIndex) async {
    final text = _referralBodyForMessage(messageIndex);
    setState(() => _exportingPdfIndex = messageIndex);

    try {
      final api = ref.read(fastApiServiceProvider);
      final result = await api.exportReferralPdf(
        referralText: text,
        childName: _child?.name ?? 'Unknown',
        childId: widget.childId,
      );

      final pdfUrl = result['pdfUrl'] as String? ?? '';
      final filename =
          result['filename'] as String? ??
          'referral_${_child?.name ?? "patient"}.pdf';

      if (_activeDraftReferralId != null && pdfUrl.isNotEmpty) {
        try {
          await ref.read(firestoreServiceProvider).updateReferralDraft(
                widget.childId,
                _activeDraftReferralId!,
                letterText: text,
                pdfCloudinaryUrl: pdfUrl,
              );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral PDF saved'),
            backgroundColor: HearTechColors.green,
          ),
        );
        if (pdfUrl.isNotEmpty) {
          try {
            final localPath = await api.downloadExportToTemp(
              fileUrl: pdfUrl,
              filename: filename,
            );
            await Share.shareXFiles([
              XFile(localPath),
            ], text: 'HearTech referral PDF');
          } catch (_) {
            final uri = Uri.parse(pdfUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _exportingPdfIndex = null);
  }

  // ── Export DOCX ────────────────────────────────────────────────────────
  Future<void> _exportDocx(int messageIndex) async {
    final text = _referralBodyForMessage(messageIndex);
    setState(() => _exportingDocxIndex = messageIndex);

    try {
      final api = ref.read(fastApiServiceProvider);
      final result = await api.exportReferralDocx(
        referralText: text,
        childName: _child?.name ?? 'Unknown',
        childId: widget.childId,
      );

      final docxUrl = result['docxUrl'] as String? ?? '';
      final filename =
          result['filename'] as String? ??
          'referral_${_child?.name ?? "patient"}.docx';

      if (mounted && docxUrl.isNotEmpty) {
        final localPath = await api.downloadExportToTemp(
          fileUrl: docxUrl,
          filename: filename,
        );
        await Share.shareXFiles([
          XFile(localPath),
        ], text: 'HearTech referral document');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Word document ready to share'),
              backgroundColor: HearTechColors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word export failed: $e'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
    if (mounted) setState(() => _exportingDocxIndex = null);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final childName = _child?.name ?? 'Loading...';
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: HearTechColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.deepTeal),
          onPressed: () => closeReferralToChildProfile(
            context,
            widget.childId,
            userRole: ref.read(userRoleProvider),
          ),
        ),
        title: Text(
          'Clinical Assistant — $childName',
          style: HearTechTextStyles.appBarTitle(color: HearTechColors.deepTeal),
        ),
        centerTitle: false,
      ),
      body: _isLoadingChild
          ? const Center(
              child: CircularProgressIndicator(color: HearTechColors.deepTeal),
            )
          : Column(
              children: [
                // ── Chat messages ────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount:
                        _messages.length + (_isGeneratingReferral ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < _messages.length) {
                        return KeyedSubtree(
                          key: ValueKey(
                            'msg-$index-${_messages[index]['role']}',
                          ),
                          child: _buildMessage(index),
                        );
                      }
                      return const KeyedSubtree(
                        key: ValueKey('generating'),
                        child: _LoadingBubble(),
                      );
                    },
                  ),
                ),

                // ── Suggestion chips ────────────────────────────────────
                _buildSuggestionChips(),

                // ── Input area ──────────────────────────────────────────
                _buildInputArea(),
              ],
            ),
    );
  }

  // ── Message bubble ─────────────────────────────────────────────────────
  Widget _buildMessage(int index) {
    final msg = _messages[index];
    final isHcw = msg['role'] == 'hcw';
    final text = msg['text'] as String;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isHcw
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: screenWidth * (isHcw ? 0.75 : 0.85),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isHcw ? HearTechColors.deepTeal : HearTechColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isHcw ? 16 : 4),
                topRight: Radius.circular(isHcw ? 4 : 16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              boxShadow: isHcw
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Text(
              text,
              style: HearTechTextStyles.body(
                color: isHcw ? HearTechColors.white : const Color(0xFF1A2E35),
              ).copyWith(fontSize: 14),
            ),
          ),

          if (!isHcw && index > 0 && msg['referralText'] != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  _openReferralLetterPage(msg['referralText'] as String),
              icon: const Icon(Icons.article_outlined, size: 18),
              label: const Text('Open referral letter'),
              style: TextButton.styleFrom(
                foregroundColor: HearTechColors.deepTeal,
              ),
            ),
            const SizedBox(height: 8),
            _buildExportButtons(index),
          ],

          if (!isHcw &&
              index > 0 &&
              msg['answerText'] != null &&
              msg['referralText'] == null &&
              (msg['text'] as String) != (msg['answerText'] as String)) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2FAFA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg['answerText'] as String,
                style: HearTechTextStyles.body(
                  color: const Color(0xFF1A2E35),
                ).copyWith(fontSize: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Export buttons ─────────────────────────────────────────────────────
  Widget _buildExportButtons(int index) {
    final isPdfLoading = _exportingPdfIndex == index;
    final isDocxLoading = _exportingDocxIndex == index;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: isPdfLoading ? null : () => _exportPdf(index),
          icon: isPdfLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HearTechColors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf, size: 18),
          label: const Text('Export PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: HearTechColors.deepTeal,
            foregroundColor: HearTechColors.white,
          ),
        ),
        OutlinedButton.icon(
          onPressed: isDocxLoading ? null : () => _exportDocx(index),
          icon: isDocxLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: HearTechColors.deepTeal,
                  ),
                )
              : const Icon(Icons.description, size: 18),
          label: const Text('Export Word'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HearTechColors.deepTeal,
            side: const BorderSide(color: HearTechColors.deepTeal),
          ),
        ),
      ],
    );
  }

  // ── Suggestion chips ───────────────────────────────────────────────────
  Widget _buildSuggestionChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _suggestionChips.map((chip) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(chip),
                onSelected: (_) {
                  _inputController.text = chip;
                  _inputController.selection = TextSelection.fromPosition(
                    TextPosition(offset: chip.length),
                  );
                },
                backgroundColor: HearTechColors.paleTeal,
                selectedColor: HearTechColors.paleTeal,
                labelStyle: HearTechTextStyles.caption(
                  color: HearTechColors.deepTeal,
                ).copyWith(fontWeight: FontWeight.w600),
                side: const BorderSide(
                  color: HearTechColors.deepTeal,
                  width: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Input area ─────────────────────────────────────────────────────────
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _inputController,
          builder: (context, value, _) {
            final canSend = value.text.trim().isNotEmpty && !_isAiLoading;
            return Row(
              children: [
                Expanded(
                  child: HearTechInputField(
                    controller: _inputController,
                    label: '',
                    hint: 'Tell the AI what to include...',
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: canSend
                        ? (_) => _sendMessage(_inputController.text)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: canSend
                      ? () => _sendMessage(_inputController.text)
                      : null,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: canSend
                          ? HearTechColors.deepTeal
                          : HearTechColors.deepTeal.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: HearTechColors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Full-screen referral letter — avoids bottom-sheet layout issues on the chat screen.
class _ReferralLetterPage extends StatelessWidget {
  final String childName;
  final String letterText;

  const _ReferralLetterPage({
    required this.childName,
    required this.letterText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.white,
      appBar: AppBar(
        backgroundColor: HearTechColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: HearTechColors.deepTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Referral — $childName',
          style: HearTechTextStyles.appBarTitle(color: HearTechColors.deepTeal),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          letterText,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xFF1A2E35),
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: HearTechColors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HearTechColors.deepTeal.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Analyzing your clinical request...',
                style: HearTechTextStyles.caption(
                  color: HearTechColors.textSecondary,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
