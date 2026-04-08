// ============================================================================
// FIRESTORE COLLECTION PATHS — Single source of truth for all paths
// ============================================================================

class FirestorePaths {
  FirestorePaths._();

  // ── Top-level collections ────────────────────────────────────────────────
  static const String users = 'users';
  static const String children = 'children';
  static const String hcwScreenings = 'hcw_screenings';
  static const String invites = 'invites';

  // ── User document ────────────────────────────────────────────────────────
  static String user(String uid) => '$users/$uid';

  // ── Child document ───────────────────────────────────────────────────────
  static String child(String childId) => '$children/$childId';

  // ── Subcollections under /children/{childId}/ ────────────────────────────
  static String screenings(String childId) => '$children/$childId/screenings';
  static String screening(String childId, String screeningId) =>
      '$children/$childId/screenings/$screeningId';

  static String teacherObservations(String childId) =>
      '$children/$childId/teacherObservations';
  static String teacherObservation(String childId, String obsId) =>
      '$children/$childId/teacherObservations/$obsId';

  static String referrals(String childId) => '$children/$childId/referrals';
  static String referral(String childId, String referralId) =>
      '$children/$childId/referrals/$referralId';

  static String speechLogs(String childId) => '$children/$childId/speechLogs';
  static String speechLog(String childId, String logId) =>
      '$children/$childId/speechLogs/$logId';

  static String notes(String childId) => '$children/$childId/notes';
  static String note(String childId, String noteId) =>
      '$children/$childId/notes/$noteId';
  // ── Notifications ────────────────────────────────────────────────────────
  static String notifications(String uid) => 'notifications/$uid/items';
  static String notification(String uid, String notifId) =>
      'notifications/$uid/items/$notifId';

  // ── HCW anonymous screenings ─────────────────────────────────────────────
  static String hcwScreening(String screeningId) =>
      '$hcwScreenings/$screeningId';

  // ── Invites ──────────────────────────────────────────────────────────────
  static String invite(String inviteId) => '$invites/$inviteId';
}
