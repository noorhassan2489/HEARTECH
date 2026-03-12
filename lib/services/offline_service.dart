import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class OfflineService {
  static const String _childrenBox = 'children_cache';
  static const String _screeningsBox = 'screenings_cache';
  static const String _syncQueueBox = 'sync_queue';

  static Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);
    
    await Hive.openBox(_childrenBox);
    await Hive.openBox(_screeningsBox);
    await Hive.openBox(_syncQueueBox);
  }

  // --- Children Cache ---
  static Future<void> cacheChildProfiles(List<Map<String, dynamic>> profiles) async {
    final box = Hive.box(_childrenBox);
    await box.clear(); // simple strategy: replace all
    for (var profile in profiles) {
      if (profile['id'] != null) {
        await box.put(profile['id'], profile);
      }
    }
  }

  static List<Map<String, dynamic>> getCachedChildProfiles() {
    final box = Hive.box(_childrenBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  // --- Offline Create/Update Queue ---
  static Future<void> queueAction(String actionType, Map<String, dynamic> payload) async {
    final box = Hive.box(_syncQueueBox);
    await box.add({
      'action': actionType,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static List<Map<String, dynamic>> getSyncQueue() {
    final box = Hive.box(_syncQueueBox);
    return box.values.cast<Map<String, dynamic>>().toList();
  }

  static Future<void> clearSyncQueue() async {
    final box = Hive.box(_syncQueueBox);
    await box.clear();
  }
}
