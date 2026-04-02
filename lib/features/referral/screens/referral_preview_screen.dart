import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

class ReferralPreviewScreen extends ConsumerStatefulWidget {
  final String childId;
  final String referralId;

  const ReferralPreviewScreen({
    super.key,
    required this.childId,
    required this.referralId,
  });

  @override
  ConsumerState<ReferralPreviewScreen> createState() => _ReferralPreviewScreenState();
}

class _ReferralPreviewScreenState extends ConsumerState<ReferralPreviewScreen> {
  String? _localPdfPath;
  String? _pdfUrl;
  String? _childName;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReferral();
  }

  Future<void> _loadReferral() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fs = ref.read(firestoreServiceProvider);
      
      // Get child name
      final child = await fs.getChild(widget.childId);
      if (child != null) {
        _childName = child.name;
      } else {
        _childName = 'Unknown Child';
      }

      // Fetch referraldoc
      final DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('children')
          .doc(widget.childId)
          .collection('referrals')
          .doc(widget.referralId)
          .get();

      if (!doc.exists) {
        throw Exception("Referral document not found.");
      }

      final data = doc.data() as Map<String, dynamic>;
      _pdfUrl = data['pdfCloudinaryUrl'];

      if (_pdfUrl == null || _pdfUrl!.isEmpty) {
        throw Exception("PDF URL is missing in the document.");
      }

      // Download PDF locally to view it
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.referralId}.pdf');
      
      if (!await file.exists()) {
        final response = await Dio().download(_pdfUrl!, file.path);
        if (response.statusCode != 200) {
          throw Exception("Failed to download PDF over network.");
        }
      }
      
      if (mounted) {
        setState(() {
          _localPdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadToDevice() async {
    if (_pdfUrl == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory(); 
      final path = '${dir.path}/heartech_referral_${widget.childId}.pdf';
      await Dio().download(_pdfUrl!, path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded to: $path'), backgroundColor: HearTechColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
  }

  void _shareLink() {
    if (_pdfUrl != null) {
      Share.share('Here is the HearTech Clinical Referral: $_pdfUrl');
    }
  }

  Future<void> _emailLink() async {
    if (_pdfUrl == null) return;
    final Uri emailUri = Uri(
      scheme: 'mailto',
      query: 'subject=HearTech Clinical Referral&body=Please review the attached clinical referral: $_pdfUrl',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email client')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        title: Text('${_childName ?? "..."} Referral', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.deepTeal),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: LoadingIndicator(message: 'Loading Referral PDF...'));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: HearTechColors.coralRed),
              const SizedBox(height: 16),
              Text('Failed to load PDF', style: HearTechTextStyles.screenTitle()),
              const SizedBox(height: 8),
              Text(_errorMessage!, style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadReferral,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HearTechColors.deepTeal,
                  foregroundColor: HearTechColors.white,
                ),
              )
            ],
          ),
        ),
      );
    }

    return PDFView(
      filePath: _localPdfPath,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: false,
      pageFling: true,
      onError: (error) {
        setState(() => _errorMessage = error.toString());
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        boxShadow: HearTechDecorations.cardShadow,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(child: _BottomAction(icon: Icons.download, label: 'Download', onTap: _downloadToDevice)),
            const SizedBox(width: 8),
            Expanded(child: _BottomAction(icon: Icons.share, label: 'Share', onTap: _shareLink)),
            const SizedBox(width: 8),
            Expanded(child: _BottomAction(icon: Icons.email, label: 'Email', onTap: _emailLink)),
          ],
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: HearTechColors.deepTeal,
        side: const BorderSide(color: HearTechColors.deepTeal),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.buttonBorderRadius),
      ),
    );
  }
}
