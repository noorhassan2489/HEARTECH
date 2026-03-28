import 'package:cloud_firestore/cloud_firestore.dart';

class InviteModel {
  final String inviteId;
  final String childId;
  final String childName;
  final String parentUid;
  final String parentName;
  final String teacherEmail;
  final String teacherUid; // can be empty string if teacher hasn't registered yet
  final String status; // 'pending' | 'accepted' | 'declined' | 'cancelled' | 'expired'
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool inviteExpirySent;

  InviteModel({
    required this.inviteId,
    required this.childId,
    required this.childName,
    required this.parentUid,
    required this.parentName,
    required this.teacherEmail,
    required this.teacherUid,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    required this.inviteExpirySent,
  });

  factory InviteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InviteModel(
      inviteId: documentId,
      childId: map['childId'] ?? '',
      childName: map['childName'] ?? '',
      parentUid: map['parentUid'] ?? '',
      parentName: map['parentName'] ?? '',
      teacherEmail: map['teacherEmail'] ?? '',
      teacherUid: map['teacherUid'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 72)),
      inviteExpirySent: map['inviteExpirySent'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
  }
}
