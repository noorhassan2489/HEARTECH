import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/user_model.dart';
import 'package:heartech/shared/models/child_model.dart';
import 'package:heartech/shared/models/screening_model.dart';
import 'package:heartech/shared/models/referral_model.dart';
import 'package:heartech/shared/models/notification_model.dart';
import 'package:heartech/shared/models/invite_model.dart';
import 'package:heartech/shared/models/speech_log_model.dart';
import 'package:heartech/shared/models/note_model.dart';
import 'package:heartech/shared/models/teacher_observation_model.dart';

/// Central Firestore service — all database reads and writes go through here.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // USERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create or update a user document.
  Future<void> setUser(UserModel user) async {
    await _db.collection(FirestorePaths.users).doc(user.uid).set(
          user.toJson(),
          SetOptions(merge: true),
        );
  }

  /// Get user by UID.
  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson(doc.data()!);
  }

  /// Stream user document.
  Stream<UserModel?> streamUser(String uid) {
    return _db.collection(FirestorePaths.users).doc(uid).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) return null;
        return UserModel.fromJson(doc.data()!);
      },
    );
  }

  /// Find user by email.
  Future<UserModel?> getUserByEmail(String email) async {
    final query = await _db
        .collection(FirestorePaths.users)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return UserModel.fromJson(query.docs.first.data());
  }

  /// Update specific fields on user document.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.users).doc(uid).update(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHILDREN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create or update a child profile.
  Future<void> setChild(ChildModel child) async {
    await _db.collection(FirestorePaths.children).doc(child.childId).set(
          child.toJson(),
          SetOptions(merge: true),
        );
  }

  /// Get child by ID.
  Future<ChildModel?> getChild(String childId) async {
    final doc =
        await _db.collection(FirestorePaths.children).doc(childId).get();
    if (!doc.exists || doc.data() == null) return null;
    return ChildModel.fromJson(doc.data()!);
  }

  /// Stream child document.
  Stream<ChildModel?> streamChild(String childId) {
    return _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ChildModel.fromJson(doc.data()!);
    });
  }

  /// Get all children where user is HCW.
  Future<List<ChildModel>> getChildrenByHcw(String hcwUid) async {
    final query = await _db
        .collection(FirestorePaths.children)
        .where('hcwIds', arrayContains: hcwUid)
        .get();
    return query.docs.map((d) => ChildModel.fromJson(d.data())).toList();
  }

  /// Stream children where user is HCW.
  Stream<List<ChildModel>> streamChildrenByHcw(String hcwUid) {
    return _db
        .collection(FirestorePaths.children)
        .where('hcwIds', arrayContains: hcwUid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChildModel.fromJson(d.data())).toList());
  }

  /// Get all children for a parent.
  Future<List<ChildModel>> getChildrenByParent(String parentUid) async {
    final query = await _db
        .collection(FirestorePaths.children)
        .where('parentId', isEqualTo: parentUid)
        .get();
    return query.docs.map((d) => ChildModel.fromJson(d.data())).toList();
  }

  /// Stream children for a parent.
  Stream<List<ChildModel>> streamChildrenByParent(String parentUid) {
    return _db
        .collection(FirestorePaths.children)
        .where('parentId', isEqualTo: parentUid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChildModel.fromJson(d.data())).toList());
  }

  /// Get all children where user is teacher.
  Stream<List<ChildModel>> streamChildrenByTeacher(String teacherUid) {
    return _db
        .collection(FirestorePaths.children)
        .where('teacherIds', arrayContains: teacherUid)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ChildModel.fromJson(d.data())).toList());
  }

  /// Update specific fields on child document.
  Future<void> updateChild(
      String childId, Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.children).doc(childId).update(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCREENINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a screening to a child's subcollection.
  Future<void> addScreening(
      String childId, ScreeningModel screening) async {
    await _db
        .collection(FirestorePaths.screenings(childId))
        .doc(screening.screeningId)
        .set(screening.toJson());
  }

  /// Get screenings for a child ordered by date desc.
  Future<List<ScreeningModel>> getScreenings(String childId) async {
    final query = await _db
        .collection(FirestorePaths.screenings(childId))
        .orderBy('date', descending: true)
        .get();
    return query.docs
        .map((d) => ScreeningModel.fromJson(d.data()))
        .toList();
  }

  /// Stream screenings for a child.
  Stream<List<ScreeningModel>> streamScreenings(String childId) {
    return _db
        .collection(FirestorePaths.screenings(childId))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ScreeningModel.fromJson(d.data()))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HCW ANONYMOUS SCREENINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Save anonymous low-risk screening.
  Future<void> saveHcwScreening(
      String screeningId, Map<String, dynamic> data) async {
    await _db
        .collection(FirestorePaths.hcwScreenings)
        .doc(screeningId)
        .set(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TEACHER OBSERVATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a teacher observation.
  Future<void> addTeacherObservation(
      String childId, TeacherObservationModel obs) async {
    await _db
        .collection(FirestorePaths.teacherObservations(childId))
        .doc(obs.obsId)
        .set(obs.toJson());
  }

  /// Stream all teacher observations for a child (parent reads).
  Stream<List<TeacherObservationModel>> streamTeacherObservations(
      String childId) {
    return _db
        .collection(FirestorePaths.teacherObservations(childId))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TeacherObservationModel.fromJson(d.data()))
            .toList());
  }

  /// Stream only this teacher's observations — query must match Firestore rules.
  Stream<List<TeacherObservationModel>> streamTeacherOwnObservations(
    String childId,
    String teacherUid,
  ) {
    if (teacherUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.teacherObservations(childId))
        .where('teacherUid', isEqualTo: teacherUid)
        .snapshots()
        .map((snap) {
          final obs = snap.docs
              .map((d) => TeacherObservationModel.fromJson(d.data()))
              .toList();
          obs.sort((a, b) => b.date.compareTo(a.date));
          return obs;
        });
  }

  /// Observations shared by parent with HCW.
  Stream<List<TeacherObservationModel>> streamHcwSharedObservations(
    String childId,
    String hcwUid,
  ) {
    if (hcwUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.teacherObservations(childId))
        .where('isVisibleToHcw', isEqualTo: true)
        .where('visibleToHcwIds', arrayContains: hcwUid)
        .snapshots()
        .map((snap) {
          final obs = snap.docs
              .map((d) => TeacherObservationModel.fromJson(d.data()))
              .toList();
          obs.sort((a, b) => b.date.compareTo(a.date));
          return obs;
        });
  }

  /// Parent toggles HCW visibility on an observation.
  Future<void> updateObservationHcwShare(
    String childId,
    String obsId, {
    required bool share,
    required List<String> hcwIds,
  }) async {
    final data = <String, dynamic>{'isVisibleToHcw': share};
    if (share && hcwIds.isNotEmpty) {
      data['visibleToHcwIds'] = hcwIds;
    } else {
      data['visibleToHcwIds'] = FieldValue.delete();
    }
    await _db
        .collection(FirestorePaths.teacherObservations(childId))
        .doc(obsId)
        .update(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFERRALS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a referral.
  Future<void> addReferral(String childId, ReferralModel referral) async {
    await _db
        .collection(FirestorePaths.referrals(childId))
        .doc(referral.referralId)
        .set(referral.toJson());
  }

  Future<ReferralModel?> getReferral(String childId, String referralId) async {
    final doc = await _db
        .collection(FirestorePaths.referrals(childId))
        .doc(referralId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return ReferralModel.fromJson(doc.data()!);
  }

  Future<void> updateReferralDraft(
    String childId,
    String referralId, {
    required String letterText,
    String? title,
    String? pdfCloudinaryUrl,
  }) async {
    final data = <String, dynamic>{
      'letterText': letterText,
      if (title != null) 'title': title,
      if (pdfCloudinaryUrl != null) 'pdfCloudinaryUrl': pdfCloudinaryUrl,
    };
    await _db
        .collection(FirestorePaths.referrals(childId))
        .doc(referralId)
        .update(data);
  }

  Future<void> finalizeReferral(
    String childId,
    String referralId, {
    required String parentId,
    String? pdfCloudinaryUrl,
  }) async {
    final data = <String, dynamic>{
      'status': ReferralStatus.finalized.firestoreValue,
      'isVisibleToParent': true,
      'parentId': parentId,
      'finalizedAt': Timestamp.fromDate(DateTime.now()),
      if (pdfCloudinaryUrl != null) 'pdfCloudinaryUrl': pdfCloudinaryUrl,
    };
    await _db
        .collection(FirestorePaths.referrals(childId))
        .doc(referralId)
        .update(data);
  }

  Future<void> discardReferral(String childId, String referralId) async {
    await _db.collection(FirestorePaths.referrals(childId)).doc(referralId).update({
      'status': ReferralStatus.discarded.firestoreValue,
    });
  }

  Future<void> updateReferralParentTeacherShare(
    String childId,
    String referralId, {
    required bool isVisibleToTeacher,
    required List<String> teacherIds,
  }) async {
    final data = <String, dynamic>{
      'isVisibleToTeacher': isVisibleToTeacher,
    };
    if (isVisibleToTeacher && teacherIds.isNotEmpty) {
      data['visibleToTeacherIds'] = teacherIds;
    } else {
      data['visibleToTeacherIds'] = FieldValue.delete();
    }
    await _db
        .collection(FirestorePaths.referrals(childId))
        .doc(referralId)
        .update(data);
  }

  /// Stream all referral documents (including soft-deleted discarded records).
  Stream<List<ReferralModel>> streamReferrals(String childId) {
    return _db
        .collection(FirestorePaths.referrals(childId))
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReferralModel.fromJson(d.data()))
            .toList());
  }

  /// Active referrals for HCW review (drafts and finalized only — discarded hidden).
  Stream<List<ReferralModel>> streamHcwReferrals(String childId) {
    return streamReferrals(childId).map(
      (referrals) => referrals
          .where((r) => r.status != ReferralStatus.discarded)
          .toList(),
    );
  }

  /// Finalized referrals shared with parent.
  Stream<List<ReferralModel>> streamParentReferrals(
    String childId,
    String parentUid,
  ) {
    if (parentUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.referrals(childId))
        .where('parentId', isEqualTo: parentUid)
        .where('isVisibleToParent', isEqualTo: true)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReferralModel.fromJson(d.data()))
            .where((r) => r.status == ReferralStatus.finalized)
            .toList());
  }

  /// Referrals parent chose to share with this teacher.
  Stream<List<ReferralModel>> streamTeacherReferrals(
    String childId,
    String teacherUid,
  ) {
    if (teacherUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.referrals(childId))
        .where('visibleToTeacherIds', arrayContains: teacherUid)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReferralModel.fromJson(d.data()))
            .where((r) =>
                r.status == ReferralStatus.finalized && r.isVisibleToTeacher)
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEECH LOGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a speech log.
  Future<void> addSpeechLog(String childId, SpeechLogModel log) async {
    await _db
        .collection(FirestorePaths.speechLogs(childId))
        .doc(log.logId)
        .set(log.toJson());
  }

  /// Stream speech logs for a child (HCW / parent — full history).
  Stream<List<SpeechLogModel>> streamSpeechLogs(String childId) {
    return _db
        .collection(FirestorePaths.speechLogs(childId))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SpeechLogModel.fromJson(d.data()))
            .toList());
  }

  /// Stream only speech logs this teacher conducted with the child.
  Stream<List<SpeechLogModel>> streamTeacherSpeechLogs(
    String childId,
    String teacherUid,
  ) {
    if (teacherUid.isEmpty) {
      return Stream.value(const []);
    }
    return _db
        .collection(FirestorePaths.speechLogs(childId))
        .where('conductedBy', isEqualTo: teacherUid)
        .snapshots()
        .map((snap) {
          final logs = snap.docs
              .map((d) => SpeechLogModel.fromJson(d.data()))
              .toList();
          logs.sort((a, b) => b.date.compareTo(a.date));
          return logs;
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Add a clinical note.
  Future<void> addNote(String childId, NoteModel note) async {
    await _db
        .collection(FirestorePaths.notes(childId))
        .doc(note.noteId)
        .set(note.toJson());
  }

  /// Add a teacher note to parent (always visible to parent).
  Future<void> addTeacherNote(String childId, NoteModel note) async {
    await addNote(childId, note);
  }

  /// Stream notes for a child ordered by createdAt desc (HCW-only internal use).
  Stream<List<NoteModel>> streamNotes(String childId) {
    return streamHcwAuthoredNotes(childId);
  }

  /// HCW-authored notes — query must match Firestore rules (authorRole hcw).
  Stream<List<NoteModel>> streamHcwAuthoredNotes(String childId) {
    return _db
        .collection(FirestorePaths.notes(childId))
        .where('authorRole', isEqualTo: 'hcw')
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((d) => NoteModel.fromJson(d.data()))
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  /// Public HCW notes shared with the parent.
  Stream<List<NoteModel>> streamParentNotes(String childId, String parentUid) {
    if (parentUid.isEmpty) {
      return Stream.value(const []);
    }
    return _db
        .collection(FirestorePaths.notes(childId))
        .where('parentId', isEqualTo: parentUid)
        .where('isPublic', isEqualTo: true)
        .where('authorRole', isEqualTo: 'hcw')
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((d) => NoteModel.fromJson(d.data()))
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  /// Stream notes shared with a linked teacher.
  Stream<List<NoteModel>> streamTeacherNotes(String childId, String teacherUid) {
    if (teacherUid.isEmpty) {
      return Stream.value(const []);
    }
    return _db
        .collection(FirestorePaths.notes(childId))
        .where('visibleToTeacherIds', arrayContains: teacherUid)
        .where('isTeacherVisible', isEqualTo: true)
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((d) => NoteModel.fromJson(d.data()))
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  /// Teacher-authored notes visible to parent.
  Stream<List<NoteModel>> streamTeacherAuthoredNotes(
    String childId,
    String parentUid,
  ) {
    if (parentUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.notes(childId))
        .where('parentId', isEqualTo: parentUid)
        .where('isPublic', isEqualTo: true)
        .where('authorRole', isEqualTo: 'teacher')
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((d) => NoteModel.fromJson(d.data()))
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  /// Teacher notes parent shared with HCW.
  Stream<List<NoteModel>> streamHcwSharedTeacherNotes(
    String childId,
    String hcwUid,
  ) {
    if (hcwUid.isEmpty) return Stream.value(const []);
    return _db
        .collection(FirestorePaths.notes(childId))
        .where('visibleToHcwIds', arrayContains: hcwUid)
        .where('isVisibleToHcw', isEqualTo: true)
        .where('authorRole', isEqualTo: 'teacher')
        .snapshots()
        .map((snap) {
          final notes = snap.docs
              .map((d) => NoteModel.fromJson(d.data()))
              .toList();
          notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notes;
        });
  }

  /// Parent toggles HCW visibility on a teacher note.
  Future<void> updateNoteHcwShare(
    String childId,
    String noteId, {
    required bool share,
    required List<String> hcwIds,
  }) async {
    final data = <String, dynamic>{'isVisibleToHcw': share};
    if (share && hcwIds.isNotEmpty) {
      data['visibleToHcwIds'] = hcwIds;
    } else {
      data['visibleToHcwIds'] = FieldValue.delete();
    }
    await _db.collection(FirestorePaths.notes(childId)).doc(noteId).update(data);
  }

  /// Backfill sharing fields on HCW notes the caller is allowed to read.
  /// Uses a scoped query — listing the whole notes collection fails under
  /// Firestore rules when parent-only teacher notes exist.
  Future<void> backfillNoteSharingFields(String childId) async {
    try {
      final child = await getChild(childId);
      if (child == null) return;

      final snap = await _db
          .collection(FirestorePaths.notes(childId))
          .where('authorRole', isEqualTo: 'hcw')
          .get();

      for (final doc in snap.docs) {
        final note = NoteModel.fromJson(doc.data());
        final updates = <String, dynamic>{};

        if (note.isPublic &&
            (note.parentId == null || note.parentId!.isEmpty) &&
            child.parentId != null &&
            child.parentId!.isNotEmpty) {
          updates['parentId'] = child.parentId;
        } else if (!note.isPublic && note.parentId != null) {
          updates['parentId'] = FieldValue.delete();
        }

        if (note.isTeacherVisible &&
            note.visibleToTeacherIds.isEmpty &&
            child.teacherIds.isNotEmpty) {
          updates['visibleToTeacherIds'] = child.teacherIds;
        } else if (!note.isTeacherVisible &&
            note.visibleToTeacherIds.isNotEmpty) {
          updates['visibleToTeacherIds'] = FieldValue.delete();
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
        }
      }
    } catch (_) {
      // Non-fatal — notes tab should still load via scoped streams.
    }
  }

  /// Update note visibility flags and denormalized sharing fields.
  Future<void> updateNoteVisibility(
    String childId,
    String noteId, {
    bool? isPublic,
    bool? isTeacherVisible,
  }) async {
    final child = await getChild(childId);
    if (child == null) return;

    final data = <String, dynamic>{};
    if (isPublic != null) {
      data['isPublic'] = isPublic;
      if (isPublic && child.parentId != null && child.parentId!.isNotEmpty) {
        data['parentId'] = child.parentId;
      } else if (!isPublic) {
        data['parentId'] = FieldValue.delete();
      }
    }
    if (isTeacherVisible != null) {
      data['isTeacherVisible'] = isTeacherVisible;
      if (isTeacherVisible && child.teacherIds.isNotEmpty) {
        data['visibleToTeacherIds'] = child.teacherIds;
      } else if (!isTeacherVisible) {
        data['visibleToTeacherIds'] = FieldValue.delete();
      }
    }
    if (data.isNotEmpty) {
      await _db.collection(FirestorePaths.notes(childId)).doc(noteId).update(data);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream notifications for a user.
  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _db
        .collection(FirestorePaths.notifications(uid))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              // Ensure notifId is always the Firestore document ID
              data['notifId'] = d.id;
              return NotificationModel.fromJson(data);
            }).toList());
  }

  /// Count unread notifications.
  Stream<int> streamUnreadCount(String uid) {
    return _db
        .collection(FirestorePaths.notifications(uid))
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark notification as read.
  Future<void> markNotificationRead(String uid, String notifId) async {
    await _db
        .collection(FirestorePaths.notifications(uid))
        .doc(notifId)
        .update({'read': true});
  }

  /// Mark all notifications as read.
  Future<void> markAllNotificationsRead(String uid) async {
    final batch = _db.batch();
    final unread = await _db
        .collection(FirestorePaths.notifications(uid))
        .where('read', isEqualTo: false)
        .get();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Delete a notification.
  Future<void> deleteNotification(String uid, String notifId) async {
    await _db
        .collection(FirestorePaths.notifications(uid))
        .doc(notifId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create an invite.
  Future<void> createInvite(InviteModel invite) async {
    await _db
        .collection(FirestorePaths.invites)
        .doc(invite.inviteId)
        .set(invite.toJson());
  }

  /// Get pending teacher invites.
  Stream<List<InviteModel>> streamPendingInvitesForTeacher(
      String teacherUid) {
    return _db
        .collection(FirestorePaths.invites)
        .where('teacherUid', isEqualTo: teacherUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InviteModel.fromJson(d.data()))
            .where((invite) => invite.isTeacherInvite)
            .toList());
  }

  /// Get pending HCW invites.
  Stream<List<InviteModel>> streamPendingInvitesForHcw(String hcwUid) {
    return _db
        .collection(FirestorePaths.invites)
        .where('hcwUid', isEqualTo: hcwUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InviteModel.fromJson(d.data()))
            .where((invite) => invite.isHcwInvite)
            .toList());
  }

  /// Get active invite for a child (from parent perspective).
  Future<InviteModel?> getActiveInviteForChild(String childId) async {
    final query = await _db
        .collection(FirestorePaths.invites)
        .where('childId', isEqualTo: childId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return InviteModel.fromJson(query.docs.first.data());
  }

  /// Update invite status.
  Future<void> updateInviteStatus(
      String inviteId, String status) async {
    await _db
        .collection(FirestorePaths.invites)
        .doc(inviteId)
        .update({'status': status});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BATCH OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get a new Firestore batch for atomic writes.
  WriteBatch batch() => _db.batch();

  /// Generate a new document ID.
  String generateId(String collection) =>
      _db.collection(collection).doc().id;
}
