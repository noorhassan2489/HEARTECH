import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/app_constants.dart';
import 'package:heartech/shared/models/child_model.dart';
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
  int? _exportingPdfIndex;
  int? _exportingDocxIndex;

  // Chat messages: {role: 'hcw'|'ai', text: String, isLoading: bool}
  final List<Map<String, dynamic>> _messages = [];

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

  @override
  void initState() {
    super.initState();
    _inputController.addListener(() => setState(() {}));
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
            'text': 'I have loaded ${_child!.name}\'s profile.\n'
                'Risk Level: $level | Score: $score/100 | Age: $age\n\n'
                'Tell me what to include in the referral, or tap a suggestion below.',
            'isLoading': false,
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
            'isLoading': false,
          });
        });
      }
    }
  }

  // ── Send message ───────────────────────────────────────────────────────
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isAiLoading || _child == null) return;

    final instruction = text.trim();
    _inputController.clear();

    setState(() {
      // HCW bubble
      _messages.add({'role': 'hcw', 'text': instruction, 'isLoading': false});
      // Loading bubble
      _messages.add({'role': 'ai', 'text': '', 'isLoading': true});
      _isAiLoading = true;
    });
    _scrollToBottom();

    try {
      final api = ref.read(fastApiServiceProvider);
      final user = await ref.read(firestoreServiceProvider)
          .getUser(ref.read(firebaseAuthServiceProvider).uid!);

      // Build flags list from medical history
      final flags = <String>[];
      if (_child!.medicalHistory.prematureBirth) flags.add('Premature birth');
      if (_child!.medicalHistory.nicuAdmission) flags.add('NICU admission');
      if (_child!.medicalHistory.familyHistoryHearingLoss) flags.add('Family history of hearing loss');
      if (_child!.medicalHistory.earInfectionCount > 0) {
        flags.add('${_child!.medicalHistory.earInfectionCount} ear infection(s)');
      }

      final bracketLabel = AppConstants.ageBracketLabels[_child!.ageBracket] ?? '';

      final result = await api.generateReferralChat(
        childData: {
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

      if (mounted) {
        setState(() {
          // Remove loading bubble
          _messages.removeWhere((m) => m['isLoading'] == true);
          // Add AI response
          _messages.add({
            'role': 'ai',
            'text': result['referralText'] as String? ?? 'No response received.',
            'isLoading': false,
          });
          _isAiLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['isLoading'] == true);
          _messages.add({
            'role': 'ai',
            'text': 'Error generating referral: $e',
            'isLoading': false,
          });
          _isAiLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  // ── Export PDF ──────────────────────────────────────────────────────────
  Future<void> _exportPdf(int messageIndex) async {
    final text = _messages[messageIndex]['text'] as String;
    setState(() => _exportingPdfIndex = messageIndex);

    try {
      final api = ref.read(fastApiServiceProvider);
      final result = await api.exportReferralPdf(
        referralText: text,
        childName: _child?.name ?? 'Unknown',
      );

      final pdfUrl = result['pdfUrl'] as String? ?? '';

      // Fire PAR-08 notification to linked parent
      if (_child?.parentId != null && _child!.parentId!.isNotEmpty) {
        try {
          await api.sendNotification(
            uid: _child!.parentId!,
            type: 'PAR-08',
            title: 'Referral Generated',
            body: 'A referral letter has been generated for ${_child!.name}.',
            relatedChildId: widget.childId,
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
        // Open the PDF URL
        if (pdfUrl.isNotEmpty) {
          final uri = Uri.parse(pdfUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final text = _messages[messageIndex]['text'] as String;
    setState(() => _exportingDocxIndex = messageIndex);

    try {
      final api = ref.read(fastApiServiceProvider);
      final result = await api.exportReferralDocx(
        referralText: text,
        childName: _child?.name ?? 'Unknown',
      );

      final docxUrl = result['docxUrl'] as String? ?? '';

      if (mounted && docxUrl.isNotEmpty) {
        await Share.share('Here is the HearTech Referral Document: $docxUrl');
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Generate Referral — $childName',
          style: HearTechTextStyles.appBarTitle(color: HearTechColors.deepTeal),
        ),
        centerTitle: false,
      ),
      body: _isLoadingChild
          ? const Center(child: CircularProgressIndicator(color: HearTechColors.deepTeal))
          : Column(
              children: [
                // ── Chat messages ────────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(i),
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
    final isLoading = msg['isLoading'] == true;
    final text = msg['text'] as String;
    final screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) return _buildLoadingBubble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isHcw ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
            child: SelectableText(
              text,
              style: HearTechTextStyles.body(
                color: isHcw
                    ? HearTechColors.white
                    : const Color(0xFF1A2E35),
              ).copyWith(fontSize: 14),
            ),
          ),

          // Export buttons below AI messages (not the initial greeting)
          if (!isHcw && index > 0) ...[
            const SizedBox(height: 8),
            _buildExportButtons(index),
          ],
        ],
      ),
    );
  }

  // ── Loading bubble (animated dots) ─────────────────────────────────────
  Widget _buildLoadingBubble() {
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
              // Three animated dots
              ...List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: HearTechColors.deepTeal.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      end: const Offset(1.2, 1.2),
                      duration: 600.ms,
                      delay: Duration(milliseconds: i * 200),
                    );
              }),
              const SizedBox(width: 10),
              Text(
                'Generating referral...',
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

  // ── Export buttons ─────────────────────────────────────────────────────
  Widget _buildExportButtons(int index) {
    final isPdfLoading = _exportingPdfIndex == index;
    final isDocxLoading = _exportingDocxIndex == index;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // PDF button
        SizedBox(
          height: 44,
          child: ElevatedButton.icon(
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
            label: const Text('Export as PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HearTechColors.deepTeal,
              foregroundColor: HearTechColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: HearTechTextStyles.caption()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // DOCX button
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
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
            label: const Text('Export as Word'),
            style: OutlinedButton.styleFrom(
              foregroundColor: HearTechColors.deepTeal,
              side: const BorderSide(color: HearTechColors.deepTeal),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: HearTechTextStyles.caption()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
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
                side: const BorderSide(color: HearTechColors.deepTeal, width: 0.5),
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
    final canSend =
        _inputController.text.trim().isNotEmpty && !_isAiLoading;

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
        child: Row(
          children: [
            Expanded(
              child: HearTechInputField(
                controller: _inputController,
                label: '',
                hint: 'Tell the AI what to include...',
                maxLines: 1,
                textInputAction: TextInputAction.send,
                onFieldSubmitted: canSend ? (_) => _sendMessage(_inputController.text) : null,
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
        ),
      ),
    );
  }
}
