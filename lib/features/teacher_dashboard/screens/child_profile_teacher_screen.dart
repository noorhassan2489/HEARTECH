import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';
import 'package:heartech/shared/models/note_model.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/features/speech/utils/speech_game_picker.dart';
import 'package:heartech/features/referral/widgets/child_referrals_tab.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:intl/intl.dart';

/// Child Profile — Teacher View (LIMITED DATA).
/// Teachers see: Risk label (no score), observations, speech sessions,
/// HCW notes marked as teacher-visible, and an "Unlink Myself" button.
class ChildProfileTeacherScreen extends ConsumerStatefulWidget {
  final String childId;

  const ChildProfileTeacherScreen({super.key, required this.childId});

  @override
  ConsumerState<ChildProfileTeacherScreen> createState() =>
      _ChildProfileTeacherScreenState();
}

class _ChildProfileTeacherScreenState
    extends ConsumerState<ChildProfileTeacherScreen> {
  bool _isRemoving = false;
  final _teacherNoteCtrl = TextEditingController();
  bool _savingTeacherNote = false;

  @override
  void dispose() {
    _teacherNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTeacherNote(ChildModel child) async {
    if (_teacherNoteCtrl.text.trim().isEmpty) return;
    setState(() => _savingTeacherNote = true);
    try {
      final fs = ref.read(firestoreServiceProvider);
      final user = ref.read(userProfileProvider);
      final noteId = fs.generateId(FirestorePaths.notes(widget.childId));
      final note = NoteModel(
        noteId: noteId,
        authorUid: user?.uid ?? '',
        authorName: user?.name ?? 'Teacher',
        authorRole: 'teacher',
        text: _teacherNoteCtrl.text.trim(),
        isPublic: true,
        parentId: child.parentId,
        createdAt: DateTime.now(),
      );
      await fs.addTeacherNote(widget.childId, note);

      _teacherNoteCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note sent to parent.'),
            backgroundColor: HearTechColors.green,
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
      if (mounted) setState(() => _savingTeacherNote = false);
    }
  }

  Future<void> _unlinkMyself(ChildModel child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HearTechColors.background,
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Unlink from ${child.name}?', style: HearTechTextStyles.sectionHeader()),
        content: Text(
          'Are you sure? You will lose access to ${child.name}\'s profile and all observation data.',
          style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: HearTechTextStyles.body(color: HearTechColors.coralRed)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRemoving = true);
    try {
      // Teacher self-removal: parentUid must be the child's parentId
      // because remove-teacher endpoint verifies parent ownership
      // But teachers can also self-remove, so we pass the child's parentId
      final fastApi = ref.read(fastApiServiceProvider);
      await fastApi.removeTeacher(
        childId: widget.childId,
        teacherUid: ref.read(firebaseAuthServiceProvider).uid!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have been unlinked from this profile.'),
            backgroundColor: HearTechColors.green,
          ),
        );
        context.go(Routes.teacherDashboard);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = ref.read(firestoreServiceProvider);
    final uid = ref.read(firebaseAuthServiceProvider).uid;

    return StreamBuilder<ChildModel?>(
      stream: firestoreService.streamChild(widget.childId),
      builder: (context, childSnap) {
        if (childSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingIndicator(message: 'Loading profile...'));
        }
        final child = childSnap.data;
        if (child == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile')),
            body: const Center(child: Text('Child not found.')),
          );
        }

        return Scaffold(
          backgroundColor: HearTechColors.background,
          appBar: AppBar(
            backgroundColor: HearTechColors.deepTeal,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: HearTechColors.white),
              onPressed: () => context.go(Routes.teacherDashboard),
            ),
            title: Text(child.name,
                style: HearTechTextStyles.sectionHeader(color: HearTechColors.white)),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Card ──────────────────────────────────
                _buildHeaderCard(child),
                const SizedBox(height: 24),

                // ── My Observations ──────────────────────────────
                _buildMyObservations(uid ?? ''),
                const SizedBox(height: 24),

                // ── Speech Sessions ──────────────────────────────
                _buildSpeechSessions(uid ?? ''),
                const SizedBox(height: 24),

                // ── Send Note to Parent ──────────────────────────
                _buildTeacherNotes(child),
                const SizedBox(height: 24),

                // ── HCW Notes (teacher-visible only) ─────────────
                _buildHcwNotes(uid ?? ''),
                const SizedBox(height: 24),

                // ── Parent-shared referrals ──────────────────────
                TeacherSharedReferralsSection(
                  childId: widget.childId,
                  teacherUid: uid ?? '',
                ),
                const SizedBox(height: 32),

                // ── Unlink Button ────────────────────────────────
                _buildUnlinkButton(child),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header Card ───────────────────────────────────────────────────────────
  Widget _buildHeaderCard(ChildModel child) {
    // Get parent name
    return FutureBuilder(
      future: child.parentId != null
          ? ref.read(firestoreServiceProvider).getUser(child.parentId!)
          : Future.value(null),
      builder: (context, parentSnap) {
        final parentName = parentSnap.data?.name ?? 'Parent';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: HearTechDecorations.cardBorderRadius,
          ),
          child: Column(
            children: [
              AvatarCircle(
                name: child.name,
                photoUrl: child.profilePhotoUrl,
                radius: 40,
              ),
              const SizedBox(height: 14),
              Text(child.name,
                  style: HearTechTextStyles.screenTitle(color: HearTechColors.white)
                      .copyWith(fontSize: 22)),
              const SizedBox(height: 4),
              Text(child.ageString,
                  style: HearTechTextStyles.body(
                      color: HearTechColors.white.withValues(alpha: 0.85))),
              const SizedBox(height: 10),
              RiskBadge(riskLevel: child.riskLevel),
              const SizedBox(height: 8),
              Text('Connected via $parentName',
                  style: HearTechTextStyles.caption(
                      color: HearTechColors.white.withValues(alpha: 0.7))),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      },
    );
  }

  // ── My Observations ───────────────────────────────────────────────────────
  Widget _buildMyObservations(String teacherUid) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Observations', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 12),
        StreamBuilder<List<TeacherObservationModel>>(
          stream: ref.read(firestoreServiceProvider)
              .streamTeacherOwnObservations(widget.childId, teacherUid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const LoadingIndicator();
            }
            if (snap.hasError) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: HearTechDecorations.cardDecoration,
                child: Text(
                  'Could not load observations.',
                  style: HearTechTextStyles.body(color: HearTechColors.coralRed),
                ),
              );
            }
            final myObs = snap.data ?? [];

            if (myObs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: HearTechDecorations.cardDecoration,
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 40,
                        color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No observations submitted yet.',
                        style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                  ],
                ),
              );
            }

            return Column(
              children: myObs.asMap().entries.map((entry) {
                final obs = entry.value;
                return _ObservationTile(obs: obs, index: entry.key);
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        HearTechButton(
          label: 'Submit New Observation',
          onPressed: () => context.go(Routes.teacherObservationFor(childId: widget.childId)),
        ),
      ],
    );
  }

  // ── Speech Sessions (teacher's own only — not parent/HCW home sessions) ───
  Widget _buildSpeechSessions(String teacherUid) {
    if (teacherUid.isEmpty) {
      return const SizedBox.shrink();
    }

    final firestoreService = ref.read(firestoreServiceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Speech Sessions', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 12),
        StreamBuilder<List<SpeechLogModel>>(
          stream: firestoreService.streamTeacherSpeechLogs(
            widget.childId,
            teacherUid,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const LoadingIndicator();
            }
            if (snap.hasError) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: HearTechDecorations.cardDecoration,
                child: Text(
                  'Could not load speech sessions.',
                  style: HearTechTextStyles.body(color: HearTechColors.coralRed),
                ),
              );
            }

            final logs = snap.data ?? [];

            if (logs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: HearTechDecorations.cardDecoration,
                child: Column(
                  children: [
                    Icon(Icons.mic_none, size: 40,
                        color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No speech sessions from you yet.',
                        style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                  ],
                ),
              );
            }

            return Column(
              children: logs.asMap().entries.map((entry) {
                final log = entry.value;
                final isShowAndTell = log.isShowAndTell;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: HearTechColors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: HearTechDecorations.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isShowAndTell
                              ? HearTechColors.deepTeal.withValues(alpha: 0.1)
                              : HearTechColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          log.gameDisplayName,
                          style: HearTechTextStyles.caption(
                            color: isShowAndTell
                                ? HearTechColors.deepTeal
                                : HearTechColors.purple,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(DateFormat('MMM d, yyyy').format(log.date),
                                style: HearTechTextStyles.caption()),
                            if (isShowAndTell && (log.expectedWord?.isNotEmpty ?? false))
                              Text(
                                'Word: ${log.expectedWord}',
                                style: HearTechTextStyles.caption(
                                  color: HearTechColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text('${log.score}%',
                          style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal)),
                    ],
                  ),
                ).animate(delay: (entry.key * 80).ms)
                    .fadeIn(duration: 200.ms);
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 12),
        HearTechButton(
          label: 'Start Speech Session',
          icon: Icons.mic,
          onPressed: () => showSpeechGamePicker(context, widget.childId),
          isSecondary: true,
        ),
      ],
    );
  }

  // ── Teacher notes to parent ───────────────────────────────────────────────
  Widget _buildTeacherNotes(ChildModel child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Send Note to Parent', style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 8),
        Text(
          'Your note is always visible to the parent. They choose whether to share it with the HCW.',
          style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _teacherNoteCtrl,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: 'Message for the parent...',
            filled: true,
            fillColor: HearTechColors.paleTeal,
            border: OutlineInputBorder(
              borderRadius: HearTechDecorations.inputBorderRadius,
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
        HearTechButton(
          label: _savingTeacherNote ? 'Sending...' : 'Send Note',
          icon: Icons.send_outlined,
          onPressed: _savingTeacherNote ? null : () => _saveTeacherNote(child),
          backgroundColor: HearTechColors.purple,
        ),
      ],
    );
  }

  // ── HCW Notes (teacher-visible) ───────────────────────────────────────────
  Widget _buildHcwNotes(String teacherUid) {
    if (teacherUid.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes from Healthcare Provider',
            style: HearTechTextStyles.sectionHeader()),
        const SizedBox(height: 12),
        StreamBuilder<List<NoteModel>>(
          stream: ref.read(firestoreServiceProvider).streamTeacherNotes(
            widget.childId,
            teacherUid,
          ),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const LoadingIndicator();
            }
            final visibleNotes = snap.data ?? [];

            if (visibleNotes.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: HearTechDecorations.cardDecoration,
                child: Column(
                  children: [
                    Icon(Icons.note_outlined, size: 40,
                        color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text('No notes have been shared by the healthcare provider.',
                        style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                        textAlign: TextAlign.center),
                  ],
                ),
              );
            }

            return Column(
              children: visibleNotes.asMap().entries.map((entry) {
                final note = entry.value;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HearTechColors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: HearTechDecorations.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.medical_services_outlined,
                              size: 16, color: HearTechColors.deepTeal),
                          const SizedBox(width: 6),
                          Text(DateFormat('MMM d, yyyy – h:mm a')
                                  .format(note.createdAt),
                              style: HearTechTextStyles.caption(
                                  color: HearTechColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(note.text, style: HearTechTextStyles.body()),
                    ],
                  ),
                ).animate(delay: (entry.key * 80).ms)
                    .fadeIn(duration: 200.ms);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Unlink Button ─────────────────────────────────────────────────────────
  Widget _buildUnlinkButton(ChildModel child) {
    return OutlinedButton.icon(
      onPressed: _isRemoving ? null : () => _unlinkMyself(child),
      icon: _isRemoving
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: HearTechColors.coralRed))
          : const Icon(Icons.link_off, size: 18),
      label: Text(_isRemoving ? 'Removing...' : 'Unlink Myself from This Profile'),
      style: OutlinedButton.styleFrom(
        foregroundColor: HearTechColors.coralRed,
        side: const BorderSide(color: HearTechColors.coralRed),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ── Observation Tile Widget ─────────────────────────────────────────────────
class _ObservationTile extends StatefulWidget {
  final TeacherObservationModel obs;
  final int index;

  const _ObservationTile({required this.obs, required this.index});

  @override
  State<_ObservationTile> createState() => _ObservationTileState();
}

class _ObservationTileState extends State<_ObservationTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final obs = widget.obs;
    final summary = obs.answers.isNotEmpty
        ? obs.answers.first.questionText
        : 'No questions';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HearTechColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: HearTechDecorations.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: HearTechColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment, size: 18, color: HearTechColors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('MMM d, yyyy').format(obs.date),
                          style: HearTechTextStyles.subtitle()),
                      Text(summary,
                          style: HearTechTextStyles.caption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: HearTechColors.textSecondary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              ...obs.answers.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: HearTechColors.deepTeal)),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(text: a.questionText,
                                style: HearTechTextStyles.caption()),
                            TextSpan(text: '  ${a.answer.toUpperCase()}',
                                style: HearTechTextStyles.caption(
                                        color: HearTechColors.deepTeal)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              if (obs.openNote != null && obs.openNote!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HearTechColors.paleTeal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Note: ${obs.openNote!}',
                      style: HearTechTextStyles.caption()),
                ),
              ],
            ],
          ],
        ),
      ),
    ).animate(delay: (widget.index * 80).ms)
        .fadeIn(duration: 200.ms)
        .slideX(begin: -0.05, end: 0);
  }
}
