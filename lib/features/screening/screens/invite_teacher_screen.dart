import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';

/// Invite Teacher screen — parent enters teacher email to send invite.
class InviteTeacherScreen extends ConsumerStatefulWidget {
  final String childId;
  const InviteTeacherScreen({super.key, required this.childId});

  @override
  ConsumerState<InviteTeacherScreen> createState() => _InviteTeacherScreenState();
}

class _InviteTeacherScreenState extends ConsumerState<InviteTeacherScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(fastApiServiceProvider).inviteTeacher(
        childId: widget.childId,
        teacherEmail: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent successfully! 🎉'), backgroundColor: HearTechColors.green),
        );
        context.go(Routes.parentDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text('Invite Teacher', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add, size: 48, color: HearTechColors.purple),
            ),
            const SizedBox(height: 24),
            Text('Link a Teacher', style: HearTechTextStyles.screenTitle()),
            const SizedBox(height: 8),
            Text(
              "Enter your child's teacher's email. They'll receive an invite to observe hearing behaviors.",
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            HearTechInputField(
              controller: _emailController,
              label: "Teacher's Email",
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendInvite(),
            ),
            const SizedBox(height: 32),
            HearTechButton(label: 'Send Invite', onPressed: _sendInvite, isLoading: _isLoading),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: HearTechColors.deepTeal, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The teacher must already have a HearTech account. They can accept the invite from their dashboard.',
                    style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
