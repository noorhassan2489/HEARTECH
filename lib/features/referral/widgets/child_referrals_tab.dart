import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/referral_model.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Referrals tab for HCW (review/finalize) and parent (view + teacher share).
class ChildReferralsTab extends ConsumerWidget {
  final String childId;
  final String viewerRole;
  final ChildModel child;

  const ChildReferralsTab({
    super.key,
    required this.childId,
    required this.viewerRole,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewerRole == 'parent') {
      final parentUid = ref.read(firebaseAuthServiceProvider).uid ?? '';
      return StreamBuilder<List<ReferralModel>>(
        stream: ref
            .read(firestoreServiceProvider)
            .streamParentReferrals(childId, parentUid),
        builder: (context, snap) => _buildBody(context, ref, snap, isParent: true),
      );
    }

    return StreamBuilder<List<ReferralModel>>(
      stream: ref.read(firestoreServiceProvider).streamHcwReferrals(childId),
      builder: (context, snap) => _buildBody(context, ref, snap, isParent: false),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AsyncSnapshot<List<ReferralModel>> snap, {
    required bool isParent,
  }) {
    if (snap.connectionState == ConnectionState.waiting) {
      return const LoadingIndicator();
    }
    if (snap.hasError) {
      return Center(
        child: Text(
          'Could not load referrals.',
          style: HearTechTextStyles.body(color: HearTechColors.coralRed),
        ),
      );
    }

    final referrals = snap.data ?? [];
    if (referrals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: HearTechColors.deepTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              isParent
                  ? 'Your healthcare worker has not finalized a referral yet.'
                  : 'No referrals yet.',
              style: HearTechTextStyles.subtitle(),
              textAlign: TextAlign.center,
            ),
            if (!isParent) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Drafts from Clinical Assistant will appear here when you generate a referral letter.',
                  style: HearTechTextStyles.caption(),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isParent) {
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: referrals.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _ParentReferralCard(
          childId: childId,
          child: child,
          referral: referrals[i],
        ),
      );
    }

    final drafts =
        referrals.where((r) => r.status == ReferralStatus.draft).toList();
    final finalized =
        referrals.where((r) => r.status == ReferralStatus.finalized).toList();

    if (drafts.isEmpty && finalized.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: HearTechColors.deepTeal.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text('No referrals yet.', style: HearTechTextStyles.subtitle()),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Drafts from Clinical Assistant will appear here when you generate a referral letter.',
                style: HearTechTextStyles.caption(),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (drafts.isNotEmpty) ...[
          Text('Drafts', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 8),
          ...drafts.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HcwReferralCard(
                childId: childId,
                child: child,
                referral: r,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (finalized.isNotEmpty) ...[
          Text('Finalized', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 8),
          ...finalized.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HcwReferralCard(
                childId: childId,
                child: child,
                referral: r,
                readOnly: true,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HcwReferralCard extends ConsumerStatefulWidget {
  final String childId;
  final ChildModel child;
  final ReferralModel referral;
  final bool readOnly;

  const _HcwReferralCard({
    required this.childId,
    required this.child,
    required this.referral,
    this.readOnly = false,
  });

  @override
  ConsumerState<_HcwReferralCard> createState() => _HcwReferralCardState();
}

class _HcwReferralCardState extends ConsumerState<_HcwReferralCard> {
  bool _busy = false;

  Future<void> _preview() async {
    if (widget.referral.pdfCloudinaryUrl != null &&
        widget.referral.pdfCloudinaryUrl!.isNotEmpty) {
      if (!mounted) return;
      context.push(
        Routes.referralPreviewFor(
          childId: widget.childId,
          referralId: widget.referral.referralId,
          role: 'hcw',
        ),
      );
      return;
    }
    final letter = widget.referral.letterText ?? '';
    if (letter.isEmpty) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Referral letter'),
        content: SingleChildScrollView(child: Text(letter)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('This referral draft will be marked as not needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard', style: TextStyle(color: HearTechColors.coralRed)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(firestoreServiceProvider).discardReferral(
            widget.childId,
            widget.referral.referralId,
          );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalize() async {
    if (widget.child.parentId == null || widget.child.parentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link a parent profile before finalizing a referral.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize referral?'),
        content: Text(
          'Share this referral with ${widget.child.name}\'s parent? '
          'They will be able to view it in their profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalize')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final api = ref.read(fastApiServiceProvider);
      String? pdfUrl = widget.referral.pdfCloudinaryUrl;
      final letter = widget.referral.letterText ?? '';
      if ((pdfUrl == null || pdfUrl.isEmpty) && letter.isNotEmpty) {
        final result = await api.exportReferralPdf(
          referralText: letter,
          childName: widget.child.name,
          childId: widget.childId,
        );
        pdfUrl = result['pdfUrl'] as String?;
      }

      await fs.finalizeReferral(
        widget.childId,
        widget.referral.referralId,
        parentId: widget.child.parentId!,
        pdfCloudinaryUrl: pdfUrl,
      );

      try {
        await api.sendNotification(
          uid: widget.child.parentId!,
          type: 'PAR-08',
          title: 'Referral Available',
          body:
              'A clinical referral has been finalized for ${widget.child.name}.',
          priority: 'high',
          navigationRoute: Routes.referralPreviewFor(
            childId: widget.childId,
            referralId: widget.referral.referralId,
            role: 'parent',
          ),
          relatedChildId: widget.childId,
        );
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Referral finalized and shared with parent.'),
            backgroundColor: HearTechColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to finalize: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.referral;
    final date = DateFormat('MMM d, yyyy • HH:mm').format(
      r.finalizedAt ?? r.generatedAt,
    );
    final title = r.title ?? ReferralModel.titleFromLetter(r.letterText);
    final statusLabel = switch (r.status) {
      ReferralStatus.draft => 'DRAFT',
      ReferralStatus.finalized => 'FINALIZED',
      ReferralStatus.discarded => 'DISCARDED',
    };
    final statusColor = switch (r.status) {
      ReferralStatus.draft => HearTechColors.warmOrange,
      ReferralStatus.finalized => HearTechColors.green,
      ReferralStatus.discarded => HearTechColors.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HearTechColors.coralRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: HearTechColors.coralRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: HearTechTextStyles.subtitle()),
                      const SizedBox(height: 4),
                      Text(date, style: HearTechTextStyles.caption()),
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: HearTechTextStyles.caption(color: statusColor),
                      ),
                    ],
                  ),
                ),
                if (!_busy)
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined,
                        color: HearTechColors.deepTeal),
                    onPressed: _preview,
                  ),
              ],
            ),
            if (!widget.readOnly && r.status == ReferralStatus.draft) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : _discard,
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HearTechColors.deepTeal,
                        foregroundColor: HearTechColors.white,
                      ),
                      onPressed: _busy ? null : _finalize,
                      child: const Text('Finalize'),
                    ),
                  ),
                ],
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(color: HearTechColors.deepTeal),
              ),
          ],
        ),
      );
  }
}

class _ParentReferralCard extends ConsumerStatefulWidget {
  final String childId;
  final ChildModel child;
  final ReferralModel referral;

  const _ParentReferralCard({
    required this.childId,
    required this.child,
    required this.referral,
  });

  @override
  ConsumerState<_ParentReferralCard> createState() => _ParentReferralCardState();
}

class _ParentReferralCardState extends ConsumerState<_ParentReferralCard> {
  bool _sharing = false;

  Future<void> _toggleTeacherShare(bool value) async {
    if (widget.child.teacherIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teacher linked to this child yet.')),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      await ref.read(firestoreServiceProvider).updateReferralParentTeacherShare(
            widget.childId,
            widget.referral.referralId,
            isVisibleToTeacher: value,
            teacherIds: List<String>.from(widget.child.teacherIds),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update sharing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openPreview() {
    context.push(
      Routes.referralPreviewFor(
        childId: widget.childId,
        referralId: widget.referral.referralId,
        role: 'parent',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.referral;
    final title = r.title ?? ReferralModel.titleFromLetter(r.letterText);
    final date = DateFormat('MMM d, yyyy').format(r.finalizedAt ?? r.generatedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: HearTechTextStyles.subtitle()),
                    Text(date, style: HearTechTextStyles.caption()),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, color: HearTechColors.deepTeal),
                onPressed: _openPreview,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: r.isVisibleToTeacher,
                onChanged: _sharing ? null : _toggleTeacherShare,
                activeThumbColor: HearTechColors.deepTeal,
              ),
              Expanded(
                child: Text(
                  'Share with teacher',
                  style: HearTechTextStyles.body(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Read-only referral list for teachers (parent-shared only).
class TeacherSharedReferralsSection extends ConsumerWidget {
  final String childId;
  final String teacherUid;

  const TeacherSharedReferralsSection({
    super.key,
    required this.childId,
    required this.teacherUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<ReferralModel>>(
      stream: ref
          .read(firestoreServiceProvider)
          .streamTeacherReferrals(childId, teacherUid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        final referrals = snap.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shared Referrals', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 8),
            Text(
              'Referrals the parent chose to share with you.',
              style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (referrals.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: HearTechDecorations.cardDecoration,
                child: Text(
                  'No referrals shared yet.',
                  style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                ),
              )
            else
              ...referrals.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: HearTechColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: HearTechDecorations.cardBorderRadius,
                    ),
                    leading: const Icon(Icons.description_outlined,
                        color: HearTechColors.deepTeal),
                    title: Text(
                      r.title ?? ReferralModel.titleFromLetter(r.letterText),
                      style: HearTechTextStyles.subtitle(),
                    ),
                    subtitle: Text(
                      DateFormat('MMM d, yyyy')
                          .format(r.finalizedAt ?? r.generatedAt),
                      style: HearTechTextStyles.caption(),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      Routes.referralPreviewFor(
                        childId: childId,
                        referralId: r.referralId,
                        role: 'teacher',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
