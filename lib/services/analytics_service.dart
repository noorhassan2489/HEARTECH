import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    try {
      final Map<String, Object>? objParams = parameters?.map(
        (key, value) => MapEntry(key, value as Object),
      );
      await _analytics.logEvent(name: name, parameters: objParams);
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> setUserId(String? id) async {
    try {
      await _analytics.setUserId(id: id);
    } catch (e) {
      print('Analytics error: $e');
    }
  }

  Future<void> setUserProperty({required String name, required String? value}) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      print('Analytics error: $e');
    }
  }
}
