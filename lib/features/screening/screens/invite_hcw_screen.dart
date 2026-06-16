import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Invite HCW screen — parent enters HCW email to send invite.
class InviteHcwScreen extends ConsumerStatefulWidget {
  final String childId;
  const InviteHcwScreen({super.key, required this.childId});

  @override
  ConsumerState<InviteHcwScreen> createState() => _InviteHcwScreenState();
}

class _InviteHcwScreenState extends ConsumerState<InviteHcwScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String _childName = '';

  @override
  void initState() {
    super.initState();
    _loadChildName();
  }

  Future<void> _loadChildName() async {
    final child = await ref.read(firestoreServiceProvider).getChild(widget.childId);
    if (mounted && child != null) {
      setState(() => _childName = child.name);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter a valid email address.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final result = await ref.read(fastApiServiceProvider).inviteHcw(
        childId: widget.childId,
        hcwEmail: email,
      );

      if (result['error'] == 'hcw_not_found') {
        setState(() {
          _errorMessage =
              'No healthcare worker found with this email. Ask them to download HearTech and create an HCW account, then try again.';
          _isLoading = false;
        });
        return;
      }
      if (result['error'] == 'hcw_already_linked') {
        setState(() {
          _errorMessage = 'This child already has a healthcare worker linked.';
          _isLoading = false;
        });
        return;
      }
      if (result['error'] == 'invite_already_pending') {
        setState(() {
          _errorMessage = 'An invite is already pending for this child.';
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        _emailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite sent!'), backgroundColor: HearTechColors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Please try again.');
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _cancelInvite(String inviteId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Cancel Invite?', style: HearTechTextStyles.sectionHeader()),
        content: Text(
          'This invite will be cancelled and the healthcare worker will not be able to accept it.',
          style: HearTechTextStyles.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep', style: HearTechTextStyles.button(color: HearTechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Cancel Invite', style: HearTechTextStyles.button(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(fastApiServiceProvider).cancelInvite(inviteId: inviteId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invite cancelled.'), backgroundColor: HearTechColors.warmOrange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(
            Routes.parentChildProfile.replaceFirst(':childId', widget.childId),
          ),
        ),
        title: Text('Invite Healthcare Worker', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services_outlined, size: 48, color: HearTechColors.deepTeal),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Invite a Healthcare Worker', style: HearTechTextStyles.screenTitle()),
            const SizedBox(height: 8),
            Text(
              "Link a new healthcare worker to $_childName's profile for screenings and clinical care.",
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            HearTechInputField(
              controller: _emailController,
              label: "Enter HCW's HearTech account email",
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _sendInvite(),
              onChanged: (_) => setState(() => _errorMessage = null),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HearTechColors.coralRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 20, color: HearTechColors.coralRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
                    ),
                  ),
                ]),
              ).animate().fadeIn(duration: 200.ms),
            ],
            const SizedBox(height: 24),
            HearTechButton(label: 'Send Invite', onPressed: _sendInvite, isLoading: _isLoading),
            const SizedBox(height: 16),
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
                    'The healthcare worker must already have a HearTech HCW account. They can accept the invite from their dashboard.',
                    style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            _buildPendingInvites(),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingInvites() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invites')
          .where('childId', isEqualTo: widget.childId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HearTechColors.coralRed.withValues(alpha: 0.08),
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Could not load pending invites. Pull to refresh or try again later.',
              style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();

        final invites = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['inviteType'] == 'hcw';
        }).toList();
        if (invites.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pending Invitations', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            ...invites.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final inviteId = data['inviteId'] ?? doc.id;
              final hcwEmail = data['hcwEmail'] ?? 'Unknown';
              final expiresAt = data['expiresAt'];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HearTechColors.white,
                  borderRadius: HearTechDecorations.cardBorderRadius,
                  border: const Border(left: BorderSide(color: HearTechColors.deepTeal, width: 4)),
                  boxShadow: HearTechDecorations.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.mail_outline, color: HearTechColors.deepTeal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(hcwEmail, style: HearTechTextStyles.subtitle())),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HearTechColors.warmOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Pending',
                          style: HearTechTextStyles.caption(color: HearTechColors.warmOrange)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    if (expiresAt != null) _CountdownText(expiresAt: expiresAt),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _cancelInvite(inviteId),
                        child: Text(
                          'Cancel Invite',
                          style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 200.ms);
            }),
          ],
        );
      },
    );
  }
}

class _CountdownText extends StatefulWidget {
  final dynamic expiresAt;
  const _CountdownText({required this.expiresAt});
  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Timer _timer;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _update();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _update());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _update() {
    DateTime expiry;
    if (widget.expiresAt is Timestamp) {
      expiry = (widget.expiresAt as Timestamp).toDate();
    } else if (widget.expiresAt is DateTime) {
      expiry = widget.expiresAt as DateTime;
    } else {
      _text = '';
      return;
    }

    final remaining = expiry.difference(DateTime.now());
    if (remaining.isNegative) {
      _text = 'Expired';
    } else {
      final hours = remaining.inHours;
      final mins = remaining.inMinutes.remainder(60);
      _text = 'Expires in ${hours}h ${mins}m';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text(_text, style: HearTechTextStyles.caption(color: HearTechColors.textSecondary));
  }
}
