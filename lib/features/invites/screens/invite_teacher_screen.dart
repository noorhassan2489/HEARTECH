import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/firestore_service.dart';

/// Screen for parents to invite a teacher to their child's profile (Section 12).
class InviteTeacherScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const InviteTeacherScreen({super.key, required this.childId, required this.childName});

  @override
  State<InviteTeacherScreen> createState() => _InviteTeacherScreenState();
}

class _InviteTeacherScreenState extends State<InviteTeacherScreen> {
  final _firestoreService = FirestoreService();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _statusMessage = 'Please enter a valid email address.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final parentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // Check if teacher exists in Firestore
      final users = await _firestoreService.searchUsersByEmail(email);
      if (users.isEmpty) {
        setState(() {
          _statusMessage = 'No teacher account found with this email. Ask them to register first.';
          _isSuccess = false;
          _isLoading = false;
        });
        return;
      }

      final teacherDoc = users.first;
      final teacherRole = teacherDoc['role'] as String?;
      if (teacherRole != 'teacher') {
        setState(() {
          _statusMessage = 'This email belongs to a ${teacherRole ?? 'non-teacher'} account. Only teachers can be invited.';
          _isSuccess = false;
          _isLoading = false;
        });
        return;
      }

      final teacherUid = teacherDoc['uid'] as String;

      // Create the invite
      await _firestoreService.createInvite({
        'parentUid': parentUid,
        'teacherUid': teacherUid,
        'childId': widget.childId,
        'childName': widget.childName,
        'teacherEmail': email,
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      setState(() {
        _statusMessage = 'Invitation sent to $email! They will see it in their Pending Invites.';
        _isSuccess = true;
        _emailController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error sending invite: $e';
        _isSuccess = false;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Invite Teacher', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Child info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.child_care, color: AppTheme.primaryTeal, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Invite a teacher to view ${widget.childName}\'s profile', style: AppTheme.bodyText)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text('Teacher\'s Email', style: AppTheme.heading2),
            const SizedBox(height: 8),
            Text(
              'Enter the email address the teacher used to register on HearTech.',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: AppTheme.inputDecoration('Teacher Email', Icons.email_outlined),
            ),
            const SizedBox(height: 24),

            // Status message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isSuccess ? AppTheme.safeGreen.withValues(alpha: 0.1) : AppTheme.accentCoral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isSuccess ? AppTheme.safeGreen : AppTheme.accentCoral),
                ),
                child: Row(
                  children: [
                    Icon(_isSuccess ? Icons.check_circle : Icons.error_outline,
                        color: _isSuccess ? AppTheme.safeGreen : AppTheme.accentCoral),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_statusMessage!, style: AppTheme.bodyText)),
                  ],
                ),
              ),

            ElevatedButton(
              onPressed: _isLoading ? null : _sendInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('SEND INVITATION'),
            ),

            const SizedBox(height: 32),

            // Info section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.info_outline, color: AppTheme.primaryTeal),
                    const SizedBox(width: 8),
                    Text('How it works', style: AppTheme.heading2.copyWith(fontSize: 16)),
                  ]),
                  const SizedBox(height: 12),
                  _buildStep('1', 'Teacher registers on HearTech with their email'),
                  _buildStep('2', 'You enter their email here and send the invite'),
                  _buildStep('3', 'Teacher accepts the invite from their dashboard'),
                  _buildStep('4', 'Teacher can now view and observe your child'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppTheme.primaryPale,
            child: Text(number, style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTheme.bodyText.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}
