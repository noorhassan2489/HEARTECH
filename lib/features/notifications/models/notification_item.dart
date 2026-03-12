import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String priority;
  final String? relatedChildId;
  final String? relatedScreeningId;
  final String? relatedReferralId;
  final String? relatedInviteId;
  final String navigationRoute;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.priority,
    this.relatedChildId,
    this.relatedScreeningId,
    this.relatedReferralId,
    this.relatedInviteId,
    required this.navigationRoute,
  });

  factory NotificationItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationItem(
      id: doc.id,
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'normal',
      relatedChildId: data['relatedChildId'],
      relatedScreeningId: data['relatedScreeningId'],
      relatedReferralId: data['relatedReferralId'],
      relatedInviteId: data['relatedInviteId'],
      navigationRoute: data['navigationRoute'] ?? '/',
    );
  }
}
