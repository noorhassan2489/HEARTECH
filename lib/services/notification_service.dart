import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:heartech/core/constants/app_constants.dart';

/// OneSignal push notification service — replaces Firebase Cloud Messaging.
class NotificationService {
  static void Function(String route)? _onNavigate;

  /// Register handler for push-tap deep links (set after GoRouter is available).
  static void setNavigationHandler(void Function(String route) onNavigate) {
    _onNavigate = onNavigate;
  }

  /// Initialize OneSignal and wire push-tap → GoRouter navigation.
  static Future<void> initialize() async {
    OneSignal.initialize(AppConstants.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data == null) return;
      final route = data['navigationRoute']?.toString();
      if (route != null && route.isNotEmpty) {
        _onNavigate?.call(route);
      }
    });
  }

  /// Call on login: register user with OneSignal.
  static Future<void> onLogin(String uid, String role) async {
    await OneSignal.login(uid);
    OneSignal.User.addTagWithKey('role', role);
  }

  /// Call on logout: clear OneSignal user.
  static Future<void> onLogout() async {
    await OneSignal.logout();
  }
}
