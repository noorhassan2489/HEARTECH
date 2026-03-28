import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String childId;
  final String name;
  final DateTime dob;
  final String gender;
  final int ageBracket;
  final String createdByHcwId;
  final String? parentId;
  final List<String> hcwIds;
  final List<String> teacherIds;
  final int riskScore;
  final String riskLevel; // 'low', 'medium', 'high'
  final String profilePhotoUrl;
  final Map<String, dynamic> medicalHistory; // prematureBirth, nicuAdmission, familyHistoryHearingLoss, earInfectionCount
  final String triggeringScreeningId;
  final Map<String, dynamic> handoverCode; // code, createdAt, expiresAt, used, attempts, expiryWarningSent
  final DateTime? lastScreeningDate;
  final DateTime? lastTeacherObservationDate;
  final DateTime? nextScreeningReminderSent;
  final DateTime? observationReminderSent;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  ChildModel({
    required this.childId,
    required this.name,
    required this.dob,
    required this.gender,
    required this.ageBracket,
    required this.createdByHcwId,
    this.parentId,
    required this.hcwIds,
    required this.teacherIds,
    required this.riskScore,
    required this.riskLevel,
    required this.profilePhotoUrl,
    required this.medicalHistory,
    required this.triggeringScreeningId,
    required this.handoverCode,
    this.lastScreeningDate,
    this.lastTeacherObservationDate,
    this.nextScreeningReminderSent,
    this.observationReminderSent,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory ChildModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChildModel(
      childId: documentId,
      name: map['name'] ?? '',
      dob: (map['dob'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gender: map['gender'] ?? '',
      ageBracket: map['ageBracket'] ?? 1,
      createdByHcwId: map['createdByHcwId'] ?? '',
      parentId: map['parentId'],
      hcwIds: List<String>.from(map['hcwIds'] ?? []),
      teacherIds: List<String>.from(map['teacherIds'] ?? []),
      riskScore: map['riskScore'] ?? 0,
      riskLevel: map['riskLevel'] ?? 'low',
      profilePhotoUrl: map['profilePhotoUrl'] ?? '',
      medicalHistory: Map<String, dynamic>.from(map['medicalHistory'] ?? {}),
      triggeringScreeningId: map['triggeringScreeningId'] ?? '',
      handoverCode: Map<String, dynamic>.from(map['handoverCode'] ?? {}),
      lastScreeningDate: (map['lastScreeningDate'] as Timestamp?)?.toDate(),
      lastTeacherObservationDate: (map['lastTeacherObservationDate'] as Timestamp?)?.toDate(),
      nextScreeningReminderSent: (map['nextScreeningReminderSent'] as Timestamp?)?.toDate(),
      observationReminderSent: (map['observationReminderSent'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdatedAt: (map['lastUpdatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'gender': gender,
      'ageBracket': ageBracket,
      'createdByHcwId': createdByHcwId,
      if (parentId != null) 'parentId': parentId,
      'hcwIds': hcwIds,
      'teacherIds': teacherIds,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'profilePhotoUrl': profilePhotoUrl,
      'medicalHistory': medicalHistory,
      'triggeringScreeningId': triggeringScreeningId,
      'handoverCode': {
        ...handoverCode,
        if (handoverCode['createdAt'] is DateTime) 'createdAt': Timestamp.fromDate(handoverCode['createdAt']),
        if (handoverCode['expiresAt'] is DateTime) 'expiresAt': Timestamp.fromDate(handoverCode['expiresAt']),
      },
      if (lastScreeningDate != null) 'lastScreeningDate': Timestamp.fromDate(lastScreeningDate!),
      if (lastTeacherObservationDate != null) 'lastTeacherObservationDate': Timestamp.fromDate(lastTeacherObservationDate!),
      if (nextScreeningReminderSent != null) 'nextScreeningReminderSent': Timestamp.fromDate(nextScreeningReminderSent!),
      if (observationReminderSent != null) 'observationReminderSent': Timestamp.fromDate(observationReminderSent!),
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }
}
