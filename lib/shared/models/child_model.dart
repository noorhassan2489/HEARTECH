import 'package:cloud_firestore/cloud_firestore.dart';

/// Child profile model — matches /children/{childId} Firestore structure.
class ChildModel {
  final String childId;
  final String name;
  final DateTime dob;
  final String gender;
  final int ageBracket; // 1-5
  final String? profilePhotoUrl;
  final String createdByHcwId;
  final String? parentId;
  final List<String> hcwIds;
  final List<String> teacherIds;
  final int riskScore; // 0-100
  final String riskLevel; // low, medium, high
  final Map<String, int?> riskBreakdown;
  final MedicalHistory medicalHistory;
  final String? triggeringScreeningId;
  final HandoverCode? handoverCode;
  final DateTime? lastScreeningDate;
  final DateTime? lastTeacherObservationDate;
  final DateTime? nextScreeningReminderSent;
  final DateTime? observationReminderSent;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  const ChildModel({
    required this.childId,
    required this.name,
    required this.dob,
    required this.gender,
    required this.ageBracket,
    this.profilePhotoUrl,
    required this.createdByHcwId,
    this.parentId,
    this.hcwIds = const [],
    this.teacherIds = const [],
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.riskBreakdown = const {},
    this.medicalHistory = const MedicalHistory(),
    this.triggeringScreeningId,
    this.handoverCode,
    this.lastScreeningDate,
    this.lastTeacherObservationDate,
    this.nextScreeningReminderSent,
    this.observationReminderSent,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory ChildModel.fromJson(Map<String, dynamic> json) {
    return ChildModel(
      childId: json['childId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      dob: _parseTimestamp(json['dob']),
      gender: json['gender'] as String? ?? '',
      ageBracket: json['ageBracket'] as int? ?? 1,
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      createdByHcwId: json['createdByHcwId'] as String? ?? '',
      parentId: json['parentId'] as String?,
      hcwIds: List<String>.from(json['hcwIds'] ?? []),
      teacherIds: List<String>.from(json['teacherIds'] ?? []),
      riskScore: json['riskScore'] as int? ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'low',
      riskBreakdown: _parseRiskBreakdown(json['riskBreakdown']),
      medicalHistory: json['medicalHistory'] != null
          ? MedicalHistory.fromJson(
              Map<String, dynamic>.from(json['medicalHistory']))
          : const MedicalHistory(),
      triggeringScreeningId: json['triggeringScreeningId'] as String?,
      handoverCode: json['handoverCode'] != null
          ? HandoverCode.fromJson(
              Map<String, dynamic>.from(json['handoverCode']))
          : null,
      lastScreeningDate: json['lastScreeningDate'] != null
          ? _parseTimestamp(json['lastScreeningDate'])
          : null,
      lastTeacherObservationDate: json['lastTeacherObservationDate'] != null
          ? _parseTimestamp(json['lastTeacherObservationDate'])
          : null,
      nextScreeningReminderSent: json['nextScreeningReminderSent'] != null
          ? _parseTimestamp(json['nextScreeningReminderSent'])
          : null,
      observationReminderSent: json['observationReminderSent'] != null
          ? _parseTimestamp(json['observationReminderSent'])
          : null,
      createdAt: _parseTimestamp(json['createdAt']),
      lastUpdatedAt: _parseTimestamp(json['lastUpdatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'childId': childId,
      'name': name,
      'dob': Timestamp.fromDate(dob),
      'gender': gender,
      'ageBracket': ageBracket,
      'profilePhotoUrl': profilePhotoUrl,
      'createdByHcwId': createdByHcwId,
      'parentId': parentId,
      'hcwIds': hcwIds,
      'teacherIds': teacherIds,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      if (riskBreakdown.isNotEmpty) 'riskBreakdown': riskBreakdown,
      'medicalHistory': medicalHistory.toJson(),
      'triggeringScreeningId': triggeringScreeningId,
      'handoverCode': handoverCode?.toJson(),
      'lastScreeningDate': lastScreeningDate != null
          ? Timestamp.fromDate(lastScreeningDate!)
          : null,
      'lastTeacherObservationDate': lastTeacherObservationDate != null
          ? Timestamp.fromDate(lastTeacherObservationDate!)
          : null,
      'nextScreeningReminderSent': nextScreeningReminderSent != null
          ? Timestamp.fromDate(nextScreeningReminderSent!)
          : null,
      'observationReminderSent': observationReminderSent != null
          ? Timestamp.fromDate(observationReminderSent!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdatedAt': Timestamp.fromDate(lastUpdatedAt),
    };
  }

  ChildModel copyWith({
    String? childId,
    String? name,
    DateTime? dob,
    String? gender,
    int? ageBracket,
    String? profilePhotoUrl,
    String? createdByHcwId,
    String? parentId,
    List<String>? hcwIds,
    List<String>? teacherIds,
    int? riskScore,
    String? riskLevel,
    Map<String, int?>? riskBreakdown,
    MedicalHistory? medicalHistory,
    String? triggeringScreeningId,
    HandoverCode? handoverCode,
    DateTime? lastScreeningDate,
    DateTime? lastTeacherObservationDate,
    DateTime? nextScreeningReminderSent,
    DateTime? observationReminderSent,
    DateTime? createdAt,
    DateTime? lastUpdatedAt,
  }) {
    return ChildModel(
      childId: childId ?? this.childId,
      name: name ?? this.name,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      ageBracket: ageBracket ?? this.ageBracket,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdByHcwId: createdByHcwId ?? this.createdByHcwId,
      parentId: parentId ?? this.parentId,
      hcwIds: hcwIds ?? this.hcwIds,
      teacherIds: teacherIds ?? this.teacherIds,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      riskBreakdown: riskBreakdown ?? this.riskBreakdown,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      triggeringScreeningId:
          triggeringScreeningId ?? this.triggeringScreeningId,
      handoverCode: handoverCode ?? this.handoverCode,
      lastScreeningDate: lastScreeningDate ?? this.lastScreeningDate,
      lastTeacherObservationDate:
          lastTeacherObservationDate ?? this.lastTeacherObservationDate,
      nextScreeningReminderSent:
          nextScreeningReminderSent ?? this.nextScreeningReminderSent,
      observationReminderSent:
          observationReminderSent ?? this.observationReminderSent,
      createdAt: createdAt ?? this.createdAt,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }

  /// Whether this child has been claimed by a parent
  bool get isClaimed => parentId != null && parentId!.isNotEmpty;

  /// Whether this child has a teacher linked
  bool get hasTeacher => teacherIds.isNotEmpty;

  /// Computed age string
  String get ageString {
    final now = DateTime.now();
    final years = now.year - dob.year;
    final months = now.month - dob.month + (now.day < dob.day ? -1 : 0);
    final totalMonths = years * 12 + months;
    if (totalMonths < 12) return '$totalMonths months';
    if (totalMonths < 24) {
      final m = totalMonths % 12;
      return m > 0 ? '1 year, $m months' : '1 year';
    }
    return '$years years';
  }

  /// Whether teacher linking is allowed (child must be 3+)
  bool get canLinkTeacher {
    final now = DateTime.now();
    final ageYears = now.difference(dob).inDays / 365.25;
    return ageYears >= 3;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }

  static Map<String, int?> _parseRiskBreakdown(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, raw) {
      final score = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
      return MapEntry(key.toString(), score);
    });
  }
}

/// Medical history embedded in child profile.
class MedicalHistory {
  final bool prematureBirth;
  final bool nicuAdmission;
  final bool familyHistoryHearingLoss;
  final int earInfectionCount;

  const MedicalHistory({
    this.prematureBirth = false,
    this.nicuAdmission = false,
    this.familyHistoryHearingLoss = false,
    this.earInfectionCount = 0,
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) {
    return MedicalHistory(
      prematureBirth: json['prematureBirth'] as bool? ?? false,
      nicuAdmission: json['nicuAdmission'] as bool? ?? false,
      familyHistoryHearingLoss:
          json['familyHistoryHearingLoss'] as bool? ?? false,
      earInfectionCount: json['earInfectionCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'prematureBirth': prematureBirth,
        'nicuAdmission': nicuAdmission,
        'familyHistoryHearingLoss': familyHistoryHearingLoss,
        'earInfectionCount': earInfectionCount,
      };
}

/// Handover code embedded in child profile.
class HandoverCode {
  final String code;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool used;
  final int attempts;
  final bool expiryWarningSent;

  const HandoverCode({
    required this.code,
    required this.createdAt,
    required this.expiresAt,
    this.used = false,
    this.attempts = 0,
    this.expiryWarningSent = false,
  });

  factory HandoverCode.fromJson(Map<String, dynamic> json) {
    return HandoverCode(
      code: json['code'] as String? ?? '',
      createdAt: ChildModel._parseTimestamp(json['createdAt']),
      expiresAt: ChildModel._parseTimestamp(json['expiresAt']),
      used: json['used'] as bool? ?? false,
      attempts: json['attempts'] as int? ?? 0,
      expiryWarningSent: json['expiryWarningSent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': used,
        'attempts': attempts,
        'expiryWarningSent': expiryWarningSent,
      };

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  Duration get timeRemaining => expiresAt.difference(DateTime.now());
}
