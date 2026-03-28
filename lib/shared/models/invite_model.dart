import 'package:cloud_firestore/cloud_firestore.dart';

/// Teacher invite record — stored under /invites/{inviteId}
class InviteModel {
  final String inviteId;
  final String childId;
  final String childName;
  final String parentUid;
  final String parentName;
  final String teacherEmail;
  final String? teacherUid;
  final String status; // pending, accepted, declined, cancelled, expired
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool inviteExpirySent;

  const InviteModel({
    required this.inviteId,
    required this.childId,
    required this.childName,
    required this.parentUid,
    required this.parentName,
    required this.teacherEmail,
    this.teacherUid,
    this.status = 'pending',
    required this.createdAt,
    required this.expiresAt,
    this.inviteExpirySent = false,
  });

  factory InviteModel.fromJson(Map<String, dynamic> json) {
    return InviteModel(
      inviteId: json['inviteId'] as String? ?? '',
      childId: json['childId'] as String? ?? '',
      childName: json['childName'] as String? ?? '',
      parentUid: json['parentUid'] as String? ?? '',
      parentName: json['parentName'] as String? ?? '',
      teacherEmail: json['teacherEmail'] as String? ?? '',
      teacherUid: json['teacherUid'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: _parseTimestamp(json['createdAt']),
      expiresAt: _parseTimestamp(json['expiresAt']),
      inviteExpirySent: json['inviteExpirySent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'inviteId': inviteId,
        'childId': childId,
        'childName': childName,
        'parentUid': parentUid,
        'parentName': parentName,
        'teacherEmail': teacherEmail,
        'teacherUid': teacherUid,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'inviteExpirySent': inviteExpirySent,
      };

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isExpired =>
      status == 'expired' || DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
