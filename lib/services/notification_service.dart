import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:heartech/core/constants/app_constants.dart';

/// OneSignal push notification service — replaces Firebase Cloud Messaging.
class NotificationService {
  /// Initialize OneSignal.
  static Future<void> initialize() async {
    OneSignal.initialize(AppConstants.oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);
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
