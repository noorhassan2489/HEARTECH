import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/providers.dart';
import '../../../shared/models/invite_model.dart';

class PendingInvitesScreen extends ConsumerWidget {
  const PendingInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final firestoreService = ref.read(firestoreServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Pending Invites', style: AppTheme.heading2)),
      body: StreamBuilder(
        stream: firestoreService.pendingInvitesForTeacher(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final invites = (snapshot.data ?? [])
              .map((m) => InviteModel.fromMap(m, m['inviteId'] ?? ''))
              .toList();

          if (invites.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mail_outline, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('No pending invites', style: AppTheme.heading2.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text('When a parent invites you, it will appear here.',
                    style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: invites.length,
            itemBuilder: (ctx, i) {
              final inv = invites[i];
              return _InviteCard(
                invite: inv,
                onAccept: () async {
                  await firestoreService.updateInvite(inv.inviteId, {'status': 'accepted', 'teacherUid': uid});
                  // Also link teacher to child
                  await firestoreService.linkUserToChild(inv.childId, uid, 'teacherIds');
                },
                onDecline: () async {
                  await firestoreService.updateInvite(inv.inviteId, {'status': 'declined'});
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InviteModel invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InviteCard({required this.invite, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.premiumCard,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primaryPale,
              child: Text(invite.childName.isNotEmpty ? invite.childName[0].toUpperCase() : '?',
                  style: AppTheme.heading2.copyWith(color: AppTheme.primaryTeal)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invite.childName, style: AppTheme.bodyText.copyWith(fontWeight: FontWeight.bold)),
              Text('From: ${invite.parentName}', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCoral,
                  side: const BorderSide(color: AppTheme.accentCoral),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onDecline,
                child: const Text('Decline'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
