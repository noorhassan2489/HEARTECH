import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_paths.dart';

/// Handles all Firestore read/write operations.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ═══════════════════════════════════════════════════════════════
  //  USERS
  // ═══════════════════════════════════════════════════════════════

  /// Create or update a user profile document.
  Future<void> setUserProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.users).doc(uid).set(
      {...data, 'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Get a user profile by UID.
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection(FirestorePaths.users).doc(uid).get();
    return doc.data();
  }

  /// Search users by email (for linking parents to children).
  Future<List<Map<String, dynamic>>> searchUsersByEmail(String email) async {
    final snap = await _db
        .collection(FirestorePaths.users)
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(5)
        .get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  /// Search users by name (partial match).
  Future<List<Map<String, dynamic>>> searchUsersByName(String name) async {
    final snap = await _db
        .collection(FirestorePaths.users)
        .where('role', isEqualTo: 'parent')
        .orderBy('name')
        .startAt([name])
        .endAt(['$name\uf8ff'])
        .limit(10)
        .get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  CHILDREN
  // ═══════════════════════════════════════════════════════════════

  /// Create a child profile (HCW only).
  Future<String> createChildProfile(Map<String, dynamic> data) async {
    final doc = await _db.collection(FirestorePaths.children).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Get a child profile by ID.
  Future<Map<String, dynamic>?> getChildProfile(String childId) async {
    final doc =
        await _db.collection(FirestorePaths.children).doc(childId).get();
    if (!doc.exists) return null;
    return {'childId': doc.id, ...doc.data()!};
  }

  /// Get all children linked to a parent.
  Stream<List<Map<String, dynamic>>> childrenByParent(String parentId) {
    return _db
        .collection(FirestorePaths.children)
        .where('parentId', isEqualTo: parentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'childId': d.id, ...d.data()}).toList());
  }

  /// Get all children linked to an HCW.
  Stream<List<Map<String, dynamic>>> childrenByHcw(String hcwId) {
    return _db
        .collection(FirestorePaths.children)
        .where('hcwIds', arrayContains: hcwId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'childId': d.id, ...d.data()}).toList());
  }

  /// Get all children linked to a teacher.
  Stream<List<Map<String, dynamic>>> childrenByTeacher(String teacherId) {
    return _db
        .collection(FirestorePaths.children)
        .where('teacherIds', arrayContains: teacherId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'childId': d.id, ...d.data()}).toList());
  }

  /// Update a child profile field.
  Future<void> updateChild(String childId, Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.children).doc(childId).update({
      ...data,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Link a teacher or HCW to a child (array-union).
  Future<void> linkUserToChild(
      String childId, String userId, String field) async {
    await _db.collection(FirestorePaths.children).doc(childId).update({
      field: FieldValue.arrayUnion([userId]),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unlink a teacher or HCW from a child.
  Future<void> unlinkUserFromChild(
      String childId, String userId, String field) async {
    await _db.collection(FirestorePaths.children).doc(childId).update({
      field: FieldValue.arrayRemove([userId]),
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  SCREENINGS
  // ═══════════════════════════════════════════════════════════════

  /// Save a follow-up screening for an existing child profile.
  Future<String> addChildScreening(
      String childId, Map<String, dynamic> data) async {
    final doc = await _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.screenings)
        .add({...data, 'date': FieldValue.serverTimestamp()});
    return doc.id;
  }

  /// Save an HCW standalone screening (no child profile).
  Future<String> addHcwScreening(Map<String, dynamic> data) async {
    final doc = await _db.collection(FirestorePaths.hcwScreenings).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Get all screenings for a child.
  Stream<List<Map<String, dynamic>>> childScreenings(String childId) {
    return _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.screenings)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'screeningId': d.id, ...d.data()})
            .toList());
  }

  /// Get HCW standalone screenings.
  Stream<List<Map<String, dynamic>>> hcwScreenings(String hcwId) {
    return _db
        .collection(FirestorePaths.hcwScreenings)
        .where('hcwId', isEqualTo: hcwId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'screeningId': d.id, ...d.data()})
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  REFERRALS
  // ═══════════════════════════════════════════════════════════════

  Future<String> addReferral(
      String childId, Map<String, dynamic> data) async {
    final doc = await _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.referrals)
        .add({...data, 'generatedAt': FieldValue.serverTimestamp()});
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> childReferrals(String childId) {
    return _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.referrals)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'referralId': d.id, ...d.data()})
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  SPEECH LOGS
  // ═══════════════════════════════════════════════════════════════

  Future<String> addSpeechLog(
      String childId, Map<String, dynamic> data) async {
    final doc = await _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.speechLogs)
        .add({...data, 'date': FieldValue.serverTimestamp()});
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> childSpeechLogs(String childId) {
    return _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.speechLogs)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => {'logId': d.id, ...d.data()}).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> addNotification(
      String uid, Map<String, dynamic> data) async {
    await _db
        .collection(FirestorePaths.notifications)
        .doc(uid)
        .collection(FirestorePaths.notifItems)
        .add({...data, 'createdAt': FieldValue.serverTimestamp(), 'read': false});
  }

  Stream<List<Map<String, dynamic>>> userNotifications(String uid) {
    return _db
        .collection(FirestorePaths.notifications)
        .doc(uid)
        .collection(FirestorePaths.notifItems)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'notifId': d.id, ...d.data()})
            .toList());
  }

  Future<void> markNotificationRead(String uid, String notifId) async {
    await _db
        .collection(FirestorePaths.notifications)
        .doc(uid)
        .collection(FirestorePaths.notifItems)
        .doc(notifId)
        .update({'read': true});
  }

  Future<void> markAllNotificationsRead(String uid) async {
    final snap = await _db
        .collection(FirestorePaths.notifications)
        .doc(uid)
        .collection(FirestorePaths.notifItems)
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String uid, String notifId) async {
    await _db
        .collection(FirestorePaths.notifications)
        .doc(uid)
        .collection(FirestorePaths.notifItems)
        .doc(notifId)
        .delete();
  }

  // ═══════════════════════════════════════════════════════════════
  //  INVITES
  // ═══════════════════════════════════════════════════════════════

  Future<String> createInvite(Map<String, dynamic> data) async {
    final doc = await _db.collection(FirestorePaths.invites).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> pendingInvitesForTeacher(String teacherUid) {
    return _db
        .collection(FirestorePaths.invites)
        .where('teacherUid', isEqualTo: teacherUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'inviteId': d.id, ...d.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> invitesForParent(String parentUid) {
    return _db
        .collection(FirestorePaths.invites)
        .where('parentUid', isEqualTo: parentUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'inviteId': d.id, ...d.data()})
            .toList());
  }

  Future<void> updateInvite(String inviteId, Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.invites).doc(inviteId).update(data);
  }

  // ═══════════════════════════════════════════════════════════════
  //  TEACHER OBSERVATIONS
  // ═══════════════════════════════════════════════════════════════

  Future<String> addTeacherObservation(
      String childId, Map<String, dynamic> data) async {
    final doc = await _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.teacherObservations)
        .add({...data, 'date': FieldValue.serverTimestamp()});
    return doc.id;
  }

  Stream<List<Map<String, dynamic>>> childTeacherObservations(String childId) {
    return _db
        .collection(FirestorePaths.children)
        .doc(childId)
        .collection(FirestorePaths.teacherObservations)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'obsId': d.id, ...d.data()})
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  AUDIT LOG
  // ═══════════════════════════════════════════════════════════════

  Future<void> writeAuditLog(Map<String, dynamic> data) async {
    await _db.collection(FirestorePaths.auditLog).add({
      ...data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
