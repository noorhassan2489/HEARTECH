// ============================================================================
// HEARTECH CONSTANTS — API URLs, service keys, app-wide constants
// ============================================================================

import 'dart:io' show Platform;

class AppConstants {
  AppConstants._();

  // ── API ──────────────────────────────────────────────────────────────────
  /// Override at build time for physical devices:
  /// `--dart-define=FASTAPI_BASE_URL=http://192.168.x.x:8000`
  static const String _fastApiBaseUrlOverride = String.fromEnvironment(
    'FASTAPI_BASE_URL',
    defaultValue: '',
  );

  /// FastAPI base URL — Android emulator uses 10.0.2.2; iOS sim uses localhost.
  /// Physical phones must set [FASTAPI_BASE_URL] to your dev machine's LAN IP.
  static String get fastApiBaseUrl {
    final override = _fastApiBaseUrlOverride.trim();
    if (override.isNotEmpty) return override;
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000'; // Android emulator → host machine
    }
    return 'http://127.0.0.1:8000'; // iOS simulator / desktop
  }

  // ── Cloudinary ───────────────────────────────────────────────────────────
  /// Override at build time: --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dl7pmkzzu',
  );
  /// Override at build time: --dart-define=CLOUDINARY_API_KEY=your_key
  static const String cloudinaryApiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '4js_Q8vWsZj5Kdjw1dtRDv_IlJQ',
  );
  static const String cloudinaryUploadPreset = 'heartech_unsigned';

  // ── OneSignal ────────────────────────────────────────────────────────────
  /// Override at build time: --dart-define=ONESIGNAL_APP_ID=your_app_id
  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '0200ac21-f1e9-417b-84de-38682079fb6b',
  );

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
