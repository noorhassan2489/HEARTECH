import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Teacher Pending Invites — accept or decline linking invitations.
class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestoreService = ref.read(firestoreServiceProvider);
    final authService = ref.read(firebaseAuthServiceProvider);
    final uid = authService.uid;

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
          onPressed: () => context.go(Routes.teacherDashboard),
        ),
        title: Text('Pending Invites', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: StreamBuilder(
        stream: firestoreService.streamPendingInvitesForTeacher(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }

          final invites = snapshot.data ?? [];
          if (invites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64,
                      color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No pending invites', style: HearTechTextStyles.subtitle()),
                  const SizedBox(height: 4),
                  Text('When a parent invites you, it will appear here.',
                      style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: invites.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final invite = invites[index];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: HearTechColors.white,
                  borderRadius: HearTechDecorations.cardBorderRadius,
                  boxShadow: HearTechDecorations.cardShadow,
                  border: const Border(
                    left: BorderSide(color: HearTechColors.purple, width: 4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: HearTechColors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.family_restroom, color: HearTechColors.purple),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.parentName, style: HearTechTextStyles.subtitle()),
                              Text('wants to link', style: HearTechTextStyles.caption()),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: HearTechColors.paleTeal,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.child_care, size: 18, color: HearTechColors.deepTeal),
                          const SizedBox(width: 8),
                          Text('Child: ${invite.childName}', style: HearTechTextStyles.body()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Received ${DateFormat('MMM d, yyyy').format(invite.createdAt)}',
                      style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
                    ),
                    if (invite.isExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('EXPIRED', style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                            .copyWith(fontWeight: FontWeight.w700)),
                      )
                    else ...[                    
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined, size: 14, color: HearTechColors.purple),
                          const SizedBox(width: 4),
                          Text(
                            'Expires in ${_timeUntil(invite.expiresAt)}',
                            style: HearTechTextStyles.caption(color: HearTechColors.purple)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!invite.isExpired)
                      Row(
                        children: [
                          Expanded(
                            child: HearTechButton(
                              label: 'Accept',
                              onPressed: () => _respond(context, ref, invite.inviteId, 'accept'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HearTechButton(
                              label: 'Decline',
                              onPressed: () => _confirmDecline(context, ref, invite.inviteId),
                              isSecondary: true,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _respond(BuildContext context, WidgetRef ref, String inviteId, String action) async {
    try {
      await ref.read(fastApiServiceProvider).respondInvite(inviteId: inviteId, action: action);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'accept' ? 'Invite accepted! 🎉' : 'Invite declined.'),
            backgroundColor: action == 'accept' ? HearTechColors.green : HearTechColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
  }

  void _confirmDecline(BuildContext context, WidgetRef ref, String inviteId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Invite?'),
        content: const Text('You will not be able to observe this child. The parent can send a new invite later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _respond(context, ref, inviteId, 'decline');
            },
            child: const Text('Decline', style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
  }

  String _timeUntil(DateTime expires) {
    final diff = expires.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}
