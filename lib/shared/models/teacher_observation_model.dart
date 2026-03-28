import 'package:cloud_firestore/cloud_firestore.dart';

/// Teacher observation — stored under /children/{childId}/teacherObservations/{obsId}
class TeacherObservationModel {
  final String obsId;
  final String teacherUid;
  final DateTime date;
  final int ageBracket;
  final List<ObservationAnswer> answers;
  final String? openNote;
  final int? riskScoreContribution;

  const TeacherObservationModel({
    required this.obsId,
    required this.teacherUid,
    required this.date,
    required this.ageBracket,
    this.answers = const [],
    this.openNote,
    this.riskScoreContribution,
  });

  factory TeacherObservationModel.fromJson(Map<String, dynamic> json) {
    return TeacherObservationModel(
      obsId: json['obsId'] as String? ?? '',
      teacherUid: json['teacherUid'] as String? ?? '',
      date: _parseTimestamp(json['date']),
      ageBracket: json['ageBracket'] as int? ?? 1,
      answers: (json['answers'] as List<dynamic>?)
              ?.map((a) =>
                  ObservationAnswer.fromJson(Map<String, dynamic>.from(a)))
              .toList() ??
          [],
      openNote: json['openNote'] as String?,
      riskScoreContribution: json['riskScoreContribution'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'obsId': obsId,
        'teacherUid': teacherUid,
        'date': Timestamp.fromDate(date),
        'ageBracket': ageBracket,
        'answers': answers.map((a) => a.toJson()).toList(),
        'openNote': openNote,
        'riskScoreContribution': riskScoreContribution,
      };

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

class ObservationAnswer {
  final String questionId;
  final String questionText;
  final String answer; // always, often, sometimes, rarely, never

  const ObservationAnswer({
    required this.questionId,
    required this.questionText,
    required this.answer,
  });

  factory ObservationAnswer.fromJson(Map<String, dynamic> json) {
    return ObservationAnswer(
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
