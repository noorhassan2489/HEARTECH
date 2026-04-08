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

  /// Stream teacher observations for a child.
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

  /// Stream referrals for a child.
  Stream<List<ReferralModel>> streamReferrals(String childId) {
    return _db
        .collection(FirestorePaths.referrals(childId))
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReferralModel.fromJson(d.data()))
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

  /// Stream speech logs for a child.
  Stream<List<SpeechLogModel>> streamSpeechLogs(String childId) {
    return _db
        .collection(FirestorePaths.speechLogs(childId))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SpeechLogModel.fromJson(d.data()))
            .toList());
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

  /// Stream notes for a child ordered by createdAt desc.
  Stream<List<NoteModel>> streamNotes(String childId) {
    return _db
        .collection(FirestorePaths.notes(childId))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => NoteModel.fromJson(d.data()))
            .toList());
  }

  /// Update note visibility flags.
  Future<void> updateNoteVisibility(
      String childId, String noteId, {bool? isPublic, bool? isTeacherVisible}) async {
    final data = <String, dynamic>{};
    if (isPublic != null) data['isPublic'] = isPublic;
    if (isTeacherVisible != null) data['isTeacherVisible'] = isTeacherVisible;
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
        .map((snap) => snap.docs
            .map((d) => NotificationModel.fromJson(d.data()))
            .toList());
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

  /// Get pending invites for a teacher.
  Stream<List<InviteModel>> streamPendingInvitesForTeacher(
      String teacherUid) {
    return _db
        .collection(FirestorePaths.invites)
        .where('teacherUid', isEqualTo: teacherUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => InviteModel.fromJson(d.data()))
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
