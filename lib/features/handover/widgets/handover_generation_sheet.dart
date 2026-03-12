import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HandoverGenerationSheet extends StatefulWidget {
  final String initialCode;
  final DateTime expiresAt;
  final String childName;
  final Future<String> Function() onRegenerate;

  const HandoverGenerationSheet({
    super.key,
    required this.initialCode,
    required this.expiresAt,
    required this.childName,
    required this.onRegenerate,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialCode,
    required DateTime expiresAt,
    required String childName,
    required Future<String> Function() onRegenerate,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HandoverGenerationSheet(
        initialCode: initialCode,
        expiresAt: expiresAt,
        childName: childName,
        onRegenerate: onRegenerate,
      ),
    );
  }

  @override
  State<HandoverGenerationSheet> createState() => _HandoverGenerationSheetState();
}

class _HandoverGenerationSheetState extends State<HandoverGenerationSheet> {
  late String _currentCode;
  late DateTime _currentExpiry;
  bool _isRegenerating = false;

  @override
  void initState() {
    super.initState();
    _currentCode = widget.initialCode;
    _currentExpiry = widget.expiresAt;
  }

  String _getTimeRemaining() {
    final diff = _currentExpiry.difference(DateTime.now());
    if (diff.isNegative) return "Expired";
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    return "$hours hrs $minutes mins remaining";
  }

  Future<void> _handleRegenerate() async {
    setState(() => _isRegenerating = true);
    try {
      final newCode = await widget.onRegenerate();
      if (mounted) {
        setState(() {
          _currentCode = newCode;
          _currentExpiry = DateTime.now().add(const Duration(hours: 24));
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _currentCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Handover code copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phonelink_ring, size: 32, color: AppTheme.primaryTeal),
            ),
            const SizedBox(height: 24),
            Text(
              'Link Profile to Parent',
              style: AppTheme.heading2,
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with the parent so they can access ${widget.childName}\'s hearing profile on their device.',
              textAlign: TextAlign.center,
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            
            // Code Display Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                children: [
                  if (_isRegenerating)
                    const SizedBox(
                      height: 48,
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryTeal),
                      ),
                    )
                  else
                    Text(
                      _currentCode,
                      style: AppTheme.display.copyWith(
                        fontSize: 48,
                        letterSpacing: 8,
                        color: AppTheme.primaryTeal,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: AppTheme.accentCoral),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeRemaining(),
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.accentCoral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: AppTheme.secondaryButton.copyWith(
                      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16)),
                    ),
                    onPressed: _isRegenerating ? null : _handleRegenerate,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: AppTheme.primaryButton.copyWith(
                      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 16)),
                    ),
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'The parent just needs to download HearTech, create an account, and enter this code on their dashboard.',
              textAlign: TextAlign.center,
              style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
