import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/invite_model.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Teacher or HCW Pending Invites — accept or decline linking invitations.
class PendingInvitesScreen extends ConsumerStatefulWidget {
  final String role; // teacher, hcw
  const PendingInvitesScreen({super.key, this.role = 'teacher'});

  @override
  ConsumerState<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends ConsumerState<PendingInvitesScreen> {
  final Set<String> _loadingInvites = {};
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Update countdown every minute
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _respond(String inviteId, String action, String childName) async {
    setState(() => _loadingInvites.add(inviteId));

    try {
      await ref.read(fastApiServiceProvider).respondInvite(
        inviteId: inviteId,
        action: action,
        inviteType: widget.role,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'accept'
                ? 'You are now linked to $childName 🎉'
                : 'Invite for $childName declined.'),
            backgroundColor: action == 'accept'
                ? HearTechColors.green
                : HearTechColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingInvites.remove(inviteId));
    }
  }

  void _confirmDecline(String inviteId, String childName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HearTechColors.background,
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Decline Invite?', style: HearTechTextStyles.screenTitle()),
        content: Text(
          'Are you sure you want to decline? You will not be able to observe this child.',
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respond(inviteId, 'decline', childName);
            },
            child: Text('Decline', style: HearTechTextStyles.body(color: HearTechColors.coralRed)
                .copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _timeUntil(DateTime expires) {
    final diff = expires.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);
    final authService = ref.read(firebaseAuthServiceProvider);
    final uid = authService.uid;
    final isHcw = widget.role == 'hcw';
    final accentColor = isHcw ? HearTechColors.deepTeal : HearTechColors.purple;
    final dashboardRoute = isHcw ? Routes.hcwDashboard : Routes.teacherDashboard;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invites')),
        body: const Center(child: Text('Not authenticated.')),
      );
    }

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(dashboardRoute),
        ),
        title: Text('Pending Invites', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: StreamBuilder<List<InviteModel>>(
        stream: isHcw
            ? firestoreService.streamPendingInvitesForHcw(uid)
            : firestoreService.streamPendingInvitesForTeacher(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator(message: 'Loading invites...');
          }

          final invites = snapshot.data ?? [];
          if (invites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mail_outline, size: 56, color: accentColor),
                    ),
                    const SizedBox(height: 20),
                    Text('No Pending Invites', style: HearTechTextStyles.screenTitle()),
                    const SizedBox(height: 8),
                    Text(
                      isHcw
                          ? 'Wait for a parent to invite you. Patient invites will appear here.'
                          : 'Wait for a parent to invite you. Invites will appear here.',
                      style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: invites.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invite = invites[index];
              final isLoading = _loadingInvites.contains(invite.inviteId);
              final expired = invite.isExpired;

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HearTechColors.white,
                  borderRadius: HearTechDecorations.cardBorderRadius,
                  boxShadow: HearTechDecorations.cardShadow,
                  border: Border(
                    left: BorderSide(color: accentColor, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Child name + parent info
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.child_care, color: accentColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.childName,
                                  style: HearTechTextStyles.subtitle()),
                              Text('Invited by ${invite.parentName}',
                                  style: HearTechTextStyles.caption(
                                      color: HearTechColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sent date
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14,
                            color: HearTechColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Sent ${DateFormat('MMM d, yyyy').format(invite.createdAt)}',
                          style: HearTechTextStyles.caption(
                              color: HearTechColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Expiry countdown
                    if (expired)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HearTechColors.coralRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('EXPIRED',
                            style: HearTechTextStyles.caption(
                                    color: HearTechColors.coralRed)
                                .copyWith(fontWeight: FontWeight.w700)),
                      )
                    else
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14,
                              color: HearTechColors.warmOrange),
                          const SizedBox(width: 4),
                          Text(
                            'Expires in ${_timeUntil(invite.expiresAt)}',
                            style: HearTechTextStyles.caption(
                                    color: HearTechColors.warmOrange)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Action buttons (hidden when expired or loading)
                    if (!expired)
                      isLoading
                          ? const Center(
                              child: SizedBox(
                                width: 28, height: 28,
                                child: CircularProgressIndicator(
                                  color: HearTechColors.deepTeal,
                                  strokeWidth: 3,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _respond(
                                        invite.inviteId, 'accept',
                                        invite.childName),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Accept'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: HearTechColors.green,
                                      foregroundColor: HearTechColors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _confirmDecline(
                                        invite.inviteId, invite.childName),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Decline'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: HearTechColors.coralRed,
                                      side: const BorderSide(
                                          color: HearTechColors.coralRed),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ],
                ),
              ).animate(delay: (index * 80).ms)
                  .fadeIn(duration: 250.ms)
                  .slideX(begin: -0.1, end: 0, duration: 250.ms);
            },
          );
        },
      ),
    );
  }
}
