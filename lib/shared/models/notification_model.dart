import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification record — stored under /notifications/{uid}/items/{notifId}
class NotificationModel {
  final String notifId;
  final String type; // HCW-01 through TCH-08
  final String title;
  final String body;
  final bool read;
  final String priority; // normal, high
  final DateTime createdAt;
  final String? relatedChildId;
  final String? relatedInviteId;
  final String? relatedReferralId;
  final String? navigationRoute; // pre-computed GoRouter path

  const NotificationModel({
    required this.notifId,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.priority = 'normal',
    required this.createdAt,
    this.relatedChildId,
    this.relatedInviteId,
    this.relatedReferralId,
    this.navigationRoute,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      notifId: json['notifId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      priority: json['priority'] as String? ?? 'normal',
      createdAt: _parseTimestamp(json['createdAt']),
      relatedChildId: json['relatedChildId'] as String?,
      relatedInviteId: json['relatedInviteId'] as String?,
      relatedReferralId: json['relatedReferralId'] as String?,
      navigationRoute: json['navigationRoute'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'notifId': notifId,
        'type': type,
        'title': title,
        'body': body,
        'read': read,
        'priority': priority,
        'createdAt': Timestamp.fromDate(createdAt),
        'relatedChildId': relatedChildId,
        'relatedInviteId': relatedInviteId,
        'relatedReferralId': relatedReferralId,
        'navigationRoute': navigationRoute,
      };

  bool get isHighPriority => priority == 'high';

  /// Returns the colour key for notification border: teal, red, orange, green, purple
  String get colorKey {
    const tealTypes = {
      'HCW-02', 'HCW-07', 'HCW-08', 'PAR-01', 'PAR-02', 'PAR-03',
      'PAR-07', 'PAR-08', 'TCH-04', 'TCH-08',
    };
    const redTypes = {
      'HCW-05', 'HCW-09', 'PAR-04', 'PAR-06', 'TCH-03', 'TCH-06',
    };
    const orangeTypes = {
      'HCW-01', 'HCW-06', 'PAR-09', 'PAR-10', 'TCH-02', 'TCH-07',
    };
    const greenTypes = {'HCW-10', 'PAR-05', 'TCH-05'};
    const purpleTypes = {'HCW-03', 'HCW-04', 'TCH-01'};

    if (tealTypes.contains(type)) return 'teal';
    if (redTypes.contains(type)) return 'red';
    if (orangeTypes.contains(type)) return 'orange';
    if (greenTypes.contains(type)) return 'green';
    if (purpleTypes.contains(type)) return 'purple';
    return 'teal';
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
