import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherObservationModel {
  final String obsId;
  final String teacherUid;
  final DateTime date;
  final int ageBracket;
  final List<Map<String, dynamic>> answers; // { questionId, questionText, answer: 'always'|'often'|'sometimes'|'rarely'|'never' }
  final String? openNote;
  final int? riskScoreContribution;

  TeacherObservationModel({
    required this.obsId,
    required this.teacherUid,
    required this.date,
    required this.ageBracket,
    required this.answers,
    this.openNote,
    this.riskScoreContribution,
  });

  factory TeacherObservationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return TeacherObservationModel(
      obsId: documentId,
      teacherUid: map['teacherUid'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ageBracket: map['ageBracket'] ?? 1,
      answers: List<Map<String, dynamic>>.from(map['answers'] ?? []),
      openNote: map['openNote'],
      riskScoreContribution: map['riskScoreContribution'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherUid': teacherUid,
      'date': Timestamp.fromDate(date),
      'ageBracket': ageBracket,
      'answers': answers,
      if (openNote != null) 'openNote': openNote,
      if (riskScoreContribution != null) 'riskScoreContribution': riskScoreContribution,
    };
  }
}
