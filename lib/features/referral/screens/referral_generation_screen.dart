import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/referral_model.dart';

/// Referral Generation Screen — calls Gemini 2.5 Flash to generate letter,
/// then ReportLab to build PDF, uploads to Cloudinary, writes to Firestore.
class ReferralGenerationScreen extends ConsumerStatefulWidget {
  final String childId;
  final String screeningId;

  const ReferralGenerationScreen({
    super.key,
    required this.childId,
    required this.screeningId,
  });

  @override
  ConsumerState<ReferralGenerationScreen> createState() =>
      _ReferralGenerationScreenState();
}

class _ReferralGenerationScreenState
    extends ConsumerState<ReferralGenerationScreen> {
  String _status = 'Generating referral letter with AI...';
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateReferral();
  }

  Future<void> _generateReferral() async {
    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final fs = ref.read(firestoreServiceProvider);
      final uid = ref.read(firebaseAuthServiceProvider).uid!;

      // Get child info
      final child = await fs.getChild(widget.childId);
      if (child == null) throw Exception('Child not found');

      // Get HCW info
      final user = await fs.getUser(uid);
      if (user == null) throw Exception('User not found');

      // Get latest screening
      final screenings = await fs.getScreenings(widget.childId);
      if (screenings.isEmpty) throw Exception('No screenings found');
      final screening = screenings.first;

      // Step 1: Generate referral text via Gemini
      if (mounted) setState(() => _status = 'Generating referral letter with AI...');

      final referralRes = await fastApi.generateReferral(
        childId: widget.childId,
        screeningId: screening.screeningId,
        riskScore: screening.riskScore,
        answers: screening.answers.map((a) => a.toJson()).toList(),
        hcwDescription: screening.clinicalNote ?? 'No clinical note provided.',
        hcwInfo: user.toJson(),
        childInfo: {
          'name': child.name,
          'age': child.ageString,
          'gender': child.gender,
          'dob': '${child.dob.year}-${child.dob.month.toString().padLeft(2, '0')}-${child.dob.day.toString().padLeft(2, '0')}',
          'medicalHistory': child.medicalHistory.toJson(),
        },
      );

      final referralText = referralRes['referralText'] as String;
      final referralId = fs.generateId(FirestorePaths.referrals(widget.childId));

      // Step 2: Generate PDF and upload to Cloudinary
      if (mounted) setState(() => _status = 'Creating PDF document...');

      final pdfRes = await fastApi.generateReferralPdf(
        childId: widget.childId,
        referralId: referralId,
        referralText: referralText,
        hcwInfo: user.toJson(),
        childInfo: {
          'name': child.name,
          'age': child.ageString,
          'gender': child.gender,
          'dob': '${child.dob.year}-${child.dob.month.toString().padLeft(2, '0')}-${child.dob.day.toString().padLeft(2, '0')}',
        },
      );

      final pdfUrl = pdfRes['pdfUrl'] as String;

      // Step 3: Write referral to Firestore
      if (mounted) setState(() => _status = 'Saving referral...');

      final referral = ReferralModel(
        referralId: referralId,
        generatedByHcwId: uid,
        generatedAt: DateTime.now(),
        pdfCloudinaryUrl: pdfUrl,
        letterText: referralText,
        screeningId: screening.screeningId,
      );
      await fs.addReferral(widget.childId, referral);

      // Step 4: Fire PAR-08 notification if parent is linked
      if (child.parentId != null && child.parentId!.isNotEmpty) {
        try {
          await fastApi.sendNotification(
            uid: child.parentId!,
            type: 'PAR-08',
            title: 'New Referral Generated',
            body: 'A clinical referral has been generated for ${child.name}.',
            priority: 'high',
            navigationRoute: '/referral-preview/${widget.childId}/$referralId',
            relatedChildId: widget.childId,
          );
        } catch (_) {
          // Non-blocking — notification failure shouldn't stop the flow
        }
      }

      // Navigate to PDF viewer
      if (mounted) {
        context.go(
          Routes.referralPreview
              .replaceFirst(':childId', widget.childId)
              .replaceFirst(':referralId', referralId),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
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
          onPressed: () => context.go(
            Routes.hcwChildProfile.replaceFirst(':childId', widget.childId),
          ),
        ),
        title: Text('Referral', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: _error != null ? _buildError() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: HearTechColors.deepTeal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description, size: 64, color: HearTechColors.deepTeal),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 800.ms),
          const SizedBox(height: 32),
          Text(_status, style: HearTechTextStyles.subtitle()),
          const SizedBox(height: 8),
          Text('This may take a moment...', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: HearTechColors.deepTeal),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: HearTechColors.coralRed),
              const SizedBox(height: 16),
              Text('Referral generation failed', style: HearTechTextStyles.screenTitle()),
              const SizedBox(height: 8),
              Text(_error ?? 'Unknown error',
                  style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _status = 'Generating referral letter with AI...';
                  });
                  _generateReferral();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HearTechColors.deepTeal,
                  foregroundColor: HearTechColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.buttonBorderRadius),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(
                  Routes.hcwChildProfile.replaceFirst(':childId', widget.childId),
                ),
                child: Text('Go Back',
                    style: HearTechTextStyles.caption(color: HearTechColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
