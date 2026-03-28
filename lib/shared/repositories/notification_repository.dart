import '../models/notification_model.dart';
import '../../services/firestore_service.dart';

/// Repository for notifications.
class NotificationRepository {
  final FirestoreService _firestore;

  NotificationRepository(this._firestore);

  /// Live stream of notifications for a user.
  Stream<List<NotificationModel>> notificationsStream(String uid) {
    return _firestore.userNotifications(uid).map((list) =>
        list.map((m) => NotificationModel.fromMap(m, m['notifId'] ?? '')).toList());
  }

  /// Mark a single notification as read.
  Future<void> markRead(String uid, String notifId) {
    return _firestore.markNotificationRead(uid, notifId);
  }

  /// Mark all notifications as read.
  Future<void> markAllRead(String uid) {
    return _firestore.markAllNotificationsRead(uid);
  }

  /// Delete a notification.
  Future<void> deleteNotification(String uid, String notifId) {
    return _firestore.deleteNotification(uid, notifId);
  }
}
