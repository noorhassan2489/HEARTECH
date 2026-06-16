import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:heartech/core/constants/app_constants.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/navigation_utils.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

class ReferralPreviewScreen extends ConsumerStatefulWidget {
  final String childId;
  final String referralId;
  final String? viewerRole;

  const ReferralPreviewScreen({
    super.key,
    required this.childId,
    required this.referralId,
    this.viewerRole,
  });

  @override
  ConsumerState<ReferralPreviewScreen> createState() =>
      _ReferralPreviewScreenState();
}

class _ReferralPreviewScreenState extends ConsumerState<ReferralPreviewScreen> {
  String? _localPdfPath;
  String? _pdfUrl;
  String? _letterText;
  String? _childName;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showLetterFallback = false;

  @override
  void initState() {
    super.initState();
    _loadReferral();
  }

  Future<void> _loadReferral() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showLetterFallback = false;
    });

    try {
      final fs = ref.read(firestoreServiceProvider);

      final child = await fs.getChild(widget.childId);
      _childName = child?.name ?? 'Unknown Child';

      final referral = await fs.getReferral(widget.childId, widget.referralId);
      if (referral == null) {
        throw Exception('Referral document not found.');
      }

      _pdfUrl = referral.pdfCloudinaryUrl;
      _letterText = referral.letterText;

      if (_pdfUrl == null || _pdfUrl!.isEmpty) {
        if (_letterText != null && _letterText!.trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _showLetterFallback = true;
              _isLoading = false;
            });
          }
          return;
        }
        throw Exception('No PDF or letter text available for this referral.');
      }

      final downloaded = await _tryDownloadPdf(_pdfUrl!, widget.referralId);
      if (downloaded != null) {
        if (mounted) {
          setState(() {
            _localPdfPath = downloaded;
            _isLoading = false;
          });
        }
        return;
      }

      if (_letterText != null && _letterText!.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _showLetterFallback = true;
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      throw Exception(
        'Could not open the referral PDF. The letter text is also unavailable.',
      );
    } catch (e) {
      if (_letterText != null && _letterText!.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _showLetterFallback = true;
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _absolutePdfUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return '${AppConstants.fastApiBaseUrl}$url';
  }

  bool _isBackendExportUrl(String url) {
    return url.contains('/api/referral-exports/');
  }

  Future<String?> _tryDownloadPdf(String url, String referralId) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$referralId.pdf');
    if (await file.exists()) {
      return file.path;
    }

    final absoluteUrl = _absolutePdfUrl(url);
    try {
      if (_isBackendExportUrl(absoluteUrl)) {
        final path = await ref.read(fastApiServiceProvider).downloadExportToTemp(
              fileUrl: absoluteUrl,
              filename: '$referralId.pdf',
            );
        return path;
      }
      await Dio().download(absoluteUrl, file.path);
      if (await file.exists()) {
        return file.path;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  void _closePreview() {
    closeReferralToChildProfile(
      context,
      widget.childId,
      viewerRole: widget.viewerRole,
      userRole: ref.read(userRoleProvider),
    );
  }

  Future<void> _downloadToDevice() async {
    if (_localPdfPath != null && await File(_localPdfPath!).exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $_localPdfPath'),
            backgroundColor: HearTechColors.green,
          ),
        );
      }
      return;
    }
    if (_pdfUrl == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/heartech_referral_${widget.childId}.pdf';
      final absoluteUrl = _absolutePdfUrl(_pdfUrl!);
      if (_isBackendExportUrl(absoluteUrl)) {
        await ref.read(fastApiServiceProvider).downloadExportToTemp(
              fileUrl: absoluteUrl,
              filename: 'heartech_referral_${widget.childId}.pdf',
            );
      } else {
        await Dio().download(absoluteUrl, path);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to: $path'),
            backgroundColor: HearTechColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
  }

  void _shareLink() {
    if (_pdfUrl != null) {
      Share.share('Here is the HearTech Clinical Referral: $_pdfUrl');
    } else if (_letterText != null && _letterText!.trim().isNotEmpty) {
      Share.share(_letterText!);
    }
  }

  Future<void> _emailLink() async {
    if (_pdfUrl != null) {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        query:
            'subject=HearTech Clinical Referral&body=Please review the attached clinical referral: $_pdfUrl',
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email client')),
        );
      }
      return;
    }

    if (_letterText != null && _letterText!.trim().isNotEmpty) {
      final Uri emailUri = Uri(
        scheme: 'mailto',
        query:
            'subject=HearTech Clinical Referral&body=${Uri.encodeComponent(_letterText!)}',
      );
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else if (mounted) {
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
        title: Text(
          '${_childName ?? "..."} Referral',
          style: HearTechTextStyles.sectionHeader(),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.deepTeal),
          onPressed: _closePreview,
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(message: 'Loading referral...'),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: HearTechColors.coralRed),
              const SizedBox(height: 16),
              Text('Failed to load referral',
                  style: HearTechTextStyles.screenTitle()),
              const SizedBox(height: 8),
              Text(_errorMessage!,
                  style: HearTechTextStyles.caption(),
                  textAlign: TextAlign.center),
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

    if (_showLetterFallback) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: SelectableText(
            _letterText ?? '',
            style: HearTechTextStyles.body(),
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

  Widget? _buildBottomBar() {
    if (widget.viewerRole == 'teacher') {
      return null;
    }

    if (_showLetterFallback) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          boxShadow: HearTechDecorations.cardShadow,
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: _BottomAction(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: _shareLink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _BottomAction(
                  icon: Icons.email,
                  label: 'Email',
                  onTap: _emailLink,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        boxShadow: HearTechDecorations.cardShadow,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: _BottomAction(
                icon: Icons.download,
                label: 'Download',
                onTap: _downloadToDevice,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BottomAction(
                icon: Icons.share,
                label: 'Share',
                onTap: _shareLink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BottomAction(
                icon: Icons.email,
                label: 'Email',
                onTap: _emailLink,
              ),
            ),
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

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
        shape: RoundedRectangleBorder(
          borderRadius: HearTechDecorations.buttonBorderRadius,
        ),
      ),
    );
  }
}
