import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class InviteTeacherDialog extends StatefulWidget {
  final Future<void> Function(String email) onInvite;

  const InviteTeacherDialog({super.key, required this.onInvite});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(String email) onInvite,
  }) {
    return showDialog(
      context: context,
      builder: (context) => InviteTeacherDialog(onInvite: onInvite),
    );
  }

  @override
  State<InviteTeacherDialog> createState() => _InviteTeacherDialogState();
}

class _InviteTeacherDialogState extends State<InviteTeacherDialog> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = "Please enter a valid email address");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onInvite(email);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.roleBg.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: AppTheme.primaryTeal),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text("Invite Teacher", style: AppTheme.heading2),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Enter the teacher's registered HearTech email address. They will receive an invitation to view this profile.",
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "Teacher's Email",
                hintText: "teacher@school.com",
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _errorMessage,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSubmit,
                  style: AppTheme.primaryButton,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Send Invite"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
