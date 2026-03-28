import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline support service — Hive caching and connectivity monitoring.
class OfflineService {
  static const String childrenBox = 'children_box';
  static const String screeningsBox = 'screenings_box';
  static const String questionnairesBox = 'questionnaires_box';
  static const String notificationsBox = 'notifications_box';
  static const String pendingSyncBox = 'pending_sync_box';

  /// Initialize Hive and open all boxes.
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox(childrenBox);
    await Hive.openBox(screeningsBox);
    await Hive.openBox(questionnairesBox);
    await Hive.openBox(notificationsBox);
    await Hive.openBox(pendingSyncBox);
  }

  /// Check if device is online.
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }

  /// Stream connectivity changes.
  static Stream<bool> connectivityStream() {
    return Connectivity().onConnectivityChanged.map(
          (result) => !result.contains(ConnectivityResult.none),
        );
  }

  /// Cache data to a Hive box.
  static Future<void> cacheData(
      String boxName, String key, dynamic data) async {
    final box = Hive.box(boxName);
    await box.put(key, data);
  }

  /// Get cached data from a Hive box.
  static dynamic getCachedData(String boxName, String key) {
    final box = Hive.box(boxName);
    return box.get(key);
  }

  /// Queue a pending write for sync.
  static Future<void> queuePendingSync(Map<String, dynamic> data) async {
    final box = Hive.box(pendingSyncBox);
    await box.add(data);
  }

  /// Get all pending sync items.
  static List<dynamic> getPendingSyncItems() {
    final box = Hive.box(pendingSyncBox);
    return box.values.toList();
  }

  /// Clear all pending sync items.
  static Future<void> clearPendingSync() async {
    final box = Hive.box(pendingSyncBox);
    await box.clear();
  }
}
