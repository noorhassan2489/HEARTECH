import 'package:cloud_firestore/cloud_firestore.dart';

/// Screening record — stored under /children/{childId}/screenings/{screeningId}
class ScreeningModel {
  final String screeningId;
  final String conductedBy; // uid
  final String conductorRole; // hcw, parent, teacher
  final DateTime date;
  final int ageBracket;
  final List<ScreeningAnswer> answers;
  final int riskScore;
  final String riskLevel;
  final String? clinicalNote;
  final String? referralId;

  const ScreeningModel({
    required this.screeningId,
    required this.conductedBy,
    required this.conductorRole,
    required this.date,
    required this.ageBracket,
    this.answers = const [],
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.clinicalNote,
    this.referralId,
  });

  factory ScreeningModel.fromJson(Map<String, dynamic> json) {
    return ScreeningModel(
      screeningId: json['screeningId'] as String? ?? '',
      conductedBy: json['conductedBy'] as String? ?? '',
      conductorRole: json['conductorRole'] as String? ?? '',
      date: _parseTimestamp(json['date']),
      ageBracket: json['ageBracket'] as int? ?? 1,
      answers: (json['answers'] as List<dynamic>?)
              ?.map((a) =>
                  ScreeningAnswer.fromJson(Map<String, dynamic>.from(a)))
              .toList() ??
          [],
      riskScore: json['riskScore'] as int? ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'low',
      clinicalNote: json['clinicalNote'] as String?,
      referralId: json['referralId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'screeningId': screeningId,
        'conductedBy': conductedBy,
        'conductorRole': conductorRole,
        'date': Timestamp.fromDate(date),
        'ageBracket': ageBracket,
        'answers': answers.map((a) => a.toJson()).toList(),
        'riskScore': riskScore,
        'riskLevel': riskLevel,
        'clinicalNote': clinicalNote,
        'referralId': referralId,
      };

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

/// A single screening question answer.
class ScreeningAnswer {
  final String questionId;
  final String questionText;
  final String answer; // yes, partial, no, not_sure, always, often, etc.

  const ScreeningAnswer({
    required this.questionId,
    required this.questionText,
    required this.answer,
  });

  factory ScreeningAnswer.fromJson(Map<String, dynamic> json) {
    return ScreeningAnswer(
      questionId: json['questionId'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'questionText': questionText,
        'answer': answer,
      };
}
