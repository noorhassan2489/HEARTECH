import 'package:cloud_firestore/cloud_firestore.dart';

class ScreeningModel {
  final String screeningId;
  final String conductedBy;
  final String conductorRole; // 'hcw', 'parent', 'teacher'
  final DateTime date;
  final int ageBracket;
  final List<Map<String, dynamic>> answers; // { questionId, questionText, answer: 'yes'|'partial'|'no'|'not_sure' }
  final int riskScore;
  final String riskLevel;
  final String? clinicalNote;
  final String? referralId;

  // Additional fields for standalone hcw_screenings (Sec 7.7)
  final String? sessionChildName;
  final DateTime? sessionDob;
  final String? sessionGender;
  final bool? profileCreated;

  ScreeningModel({
    required this.screeningId,
    required this.conductedBy,
    required this.conductorRole,
    required this.date,
    required this.ageBracket,
    required this.answers,
    required this.riskScore,
    required this.riskLevel,
    this.clinicalNote,
    this.referralId,
    this.sessionChildName,
    this.sessionDob,
    this.sessionGender,
    this.profileCreated,
  });

  factory ScreeningModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ScreeningModel(
      screeningId: documentId,
      conductedBy: map['conductedBy'] ?? map['hcwId'] ?? '', // map both normal and standalone styles
      conductorRole: map['conductorRole'] ?? 'hcw',
      date: (map['date'] as Timestamp?)?.toDate() ?? (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ageBracket: map['ageBracket'] ?? 1,
      answers: List<Map<String, dynamic>>.from(map['answers'] ?? []),
      riskScore: map['riskScore'] ?? 0,
      riskLevel: map['riskLevel'] ?? 'low',
      clinicalNote: map['clinicalNote'],
      referralId: map['referralId'],
      sessionChildName: map['sessionChildName'],
      sessionDob: (map['sessionDob'] as Timestamp?)?.toDate(),
      sessionGender: map['sessionGender'],
      profileCreated: map['profileCreated'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conductedBy': conductedBy,
      'conductorRole': conductorRole,
      'date': Timestamp.fromDate(date),
      'ageBracket': ageBracket,
      'answers': answers,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      if (clinicalNote != null) 'clinicalNote': clinicalNote,
      if (referralId != null) 'referralId': referralId,
      if (sessionChildName != null) 'sessionChildName': sessionChildName,
      if (sessionDob != null) 'sessionDob': Timestamp.fromDate(sessionDob!),
      if (sessionGender != null) 'sessionGender': sessionGender,
      if (profileCreated != null) 'profileCreated': profileCreated,
    };
  }
}
