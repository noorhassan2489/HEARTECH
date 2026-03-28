/// Firestore collection & sub-collection path constants.
class FirestorePaths {
  FirestorePaths._();

  // ─── Top-level collections ──────────────────────────────────────
  static const String users = 'users';
  static const String children = 'children';
  static const String hcwScreenings = 'hcw_screenings';
  static const String notifications = 'notifications';
  static const String invites = 'invites';
  static const String auditLog = 'audit_log';

  // ─── Sub-collections under /children/{childId}/ ─────────────────
  static const String screenings = 'screenings';
  static const String referrals = 'referrals';
  static const String speechLogs = 'speechLogs';
  static const String teacherObservations = 'teacherObservations';

  // ─── Sub-collection under /notifications/{uid}/ ─────────────────
  static const String notifItems = 'items';

  // ─── Helper paths ───────────────────────────────────────────────
  static String userDoc(String uid) => '$users/$uid';
  static String childDoc(String childId) => '$children/$childId';
  static String childScreenings(String childId) =>
      '$children/$childId/$screenings';
  static String childReferrals(String childId) =>
      '$children/$childId/$referrals';
  static String childSpeechLogs(String childId) =>
      '$children/$childId/$speechLogs';
  static String userNotifications(String uid) =>
      '$notifications/$uid/$notifItems';
  static String childTeacherObservations(String childId) =>
      '$children/$childId/$teacherObservations';
  static String inviteDoc(String inviteId) => '$invites/$inviteId';
}
