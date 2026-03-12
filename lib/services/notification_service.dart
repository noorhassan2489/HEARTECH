import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Initialize OneSignal. Call this in main.dart after Firebase initialization.
  Future<void> init() async {
    try {
      // Remove this method to stop OneSignal Debugging
      OneSignal.Debug.setLogLevel(OSLogLevel.verbose);

      // The prompt does not specify a real App ID, using a placeholder
      // For production, replace with actual OneSignal App ID
      // You should set this in an environment config
      OneSignal.initialize("YOUR-ONESIGNAL-APP-ID");

      // The prompt mentions in-app messages and push, prompt user for push permission
      OneSignal.Notifications.requestPermission(true).then((bool accepted) {
        if (kDebugMode) {
          print("Accepted permission: $accepted");
        }
      });
      
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing OneSignal: $e");
      }
    }
  }

  /// Register a user ID with OneSignal so we can target them via the REST API in backend
  Future<void> setExternalUserId(String uid) async {
    try {
      await OneSignal.login(uid);
    } catch (e) {
      if (kDebugMode) {
        print("Error setting OneSignal external user ID: $e");
      }
    }
  }

  /// Remove user ID on logout
  Future<void> removeExternalUserId() async {
    try {
      await OneSignal.logout();
    } catch (e) {
      if (kDebugMode) {
        print("Error removing OneSignal external user ID: $e");
      }
    }
  }
}
