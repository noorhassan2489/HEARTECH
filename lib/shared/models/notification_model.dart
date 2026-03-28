import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String type; // e.g. 'HCW-05'
  final String title;
  final String body;
  final bool read;
  final String priority; // 'normal' | 'high'
  final DateTime createdAt;
  final String? relatedChildId;
  final String? relatedScreeningId;
  final String? relatedReferralId;
  final String? relatedInviteId;
  final String navigationRoute; // GoRouter deep link

  NotificationModel({
    required this.notifId,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.priority,
    required this.createdAt,
    this.relatedChildId,
    this.relatedScreeningId,
    this.relatedReferralId,
    this.relatedInviteId,
    required this.navigationRoute,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return NotificationModel(
      notifId: documentId,
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      read: map['read'] ?? false,
      priority: map['priority'] ?? 'normal',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      relatedChildId: map['relatedChildId'],
      relatedScreeningId: map['relatedScreeningId'],
      relatedReferralId: map['relatedReferralId'],
      relatedInviteId: map['relatedInviteId'],
      navigationRoute: map['navigationRoute'] ?? '/',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'read': read,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      if (relatedChildId != null) 'relatedChildId': relatedChildId,
      if (relatedScreeningId != null) 'relatedScreeningId': relatedScreeningId,
      if (relatedReferralId != null) 'relatedReferralId': relatedReferralId,
      if (relatedInviteId != null) 'relatedInviteId': relatedInviteId,
      'navigationRoute': navigationRoute,
    };
  }
}
