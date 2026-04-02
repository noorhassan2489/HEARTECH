// ============================================================================
// HEARTECH CONSTANTS — API URLs, service keys, app-wide constants
// ============================================================================

class AppConstants {
  AppConstants._();

  // ── API ──────────────────────────────────────────────────────────────────
  /// FastAPI base URL (Google Cloud Run)
  /// Replace with your deployed Cloud Run URL
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  // ── Cloudinary ───────────────────────────────────────────────────────────
  /// Replace with your Cloudinary cloud name from dashboard
  static const String cloudinaryCloudName = 'dl7pmkzzu';
  static const String cloudinaryApiKey = '4js_Q8vWsZj5Kdjw1dtRDv_IlJQ';
  static const String cloudinaryUploadPreset = 'heartech_unsigned';

  // ── OneSignal ────────────────────────────────────────────────────────────
  /// Replace with your OneSignal App ID
  static const String oneSignalAppId = '0200ac21-f1e9-417b-84de-38682079fb6b';

  // ── Handover Code ────────────────────────────────────────────────────────
  static const int handoverCodeLength = 6;
  static const Duration handoverCodeExpiry = Duration(hours: 24);
  static const int handoverCodeMaxAttempts = 5;

  /// Characters excluded from handover codes (avoid confusion: 0/O, 1/I)
  static const String handoverCodeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ── Invite ───────────────────────────────────────────────────────────────
  static const Duration inviteExpiry = Duration(hours: 72);

  // ── Screening ────────────────────────────────────────────────────────────
  static const int totalAgeBrackets = 5;

  // Age bracket boundaries in months
  static const Map<int, String> ageBracketLabels = {
    1: '0-6 months',
    2: '7-12 months',
    3: '1-2 years',
    4: '3-5 years',
    5: '6-12 years',
  };

  // Risk thresholds
  static const int lowRiskMax = 33;
  static const int mediumRiskMax = 66;
  // 67-100 = high risk

  static String riskLevelFromScore(int score) {
    if (score <= lowRiskMax) return 'low';
    if (score <= mediumRiskMax) return 'medium';
    return 'high';
  }

  // ── Offline ──────────────────────────────────────────────────────────────
  static const int maxCachedScreenings = 50;
  static const int maxCachedNotifications = 20;

  // ── Notification reminder intervals ──────────────────────────────────────
  static const int hcwFollowUpHighRiskDays = 14;
  static const int hcwFollowUpMediumRiskDays = 30;
  static const int parentHomeScreeningReminderDays = 30;
  static const int teacherObservationReminderDays = 14;

  // ── Disclaimer ───────────────────────────────────────────────────────────
  static const String disclaimer =
      'HearTech is a screening tool, not a diagnosis. '
      'Always consult a qualified healthcare professional.';

  // ── Teacher access minimum age ───────────────────────────────────────────
  static const int teacherMinAgeYears = 3;
}
