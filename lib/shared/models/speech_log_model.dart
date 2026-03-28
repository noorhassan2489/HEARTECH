import 'package:cloud_firestore/cloud_firestore.dart';

class SpeechLogModel {
  final String logId;
  final String game; // 'showAndTell' | 'lingSix'
  final String conductedBy;
  final String conductorRole;
  final DateTime date;
  final int score;

  // Show & Tell specific
  final String? whisperTranscript;
  final String? expectedWord;
  final int? matchScore;
  final String? clarityRating;
  final List<String>? phonemesMissed;

  // Ling Six specific
  final List<Map<String, dynamic>>? lingResults; // { sound, heard: boolean }
  final String? frequencyFlag;

  // Shared
  final String? teacherNote;
  final String? aiAnalysisSummary;

  SpeechLogModel({
    required this.logId,
    required this.game,
    required this.conductedBy,
    required this.conductorRole,
    required this.date,
    required this.score,
    this.whisperTranscript,
    this.expectedWord,
    this.matchScore,
    this.clarityRating,
    this.phonemesMissed,
    this.lingResults,
    this.frequencyFlag,
    this.teacherNote,
    this.aiAnalysisSummary,
  });

  factory SpeechLogModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SpeechLogModel(
      logId: documentId,
      game: map['game'] ?? '',
      conductedBy: map['conductedBy'] ?? '',
      conductorRole: map['conductorRole'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      score: map['score'] ?? 0,
      whisperTranscript: map['whisperTranscript'],
      expectedWord: map['expectedWord'],
      matchScore: map['matchScore'],
      clarityRating: map['clarityRating'],
      phonemesMissed: map['phonemesMissed'] != null ? List<String>.from(map['phonemesMissed']) : null,
      lingResults: map['lingResults'] != null ? List<Map<String, dynamic>>.from(map['lingResults']) : null,
      frequencyFlag: map['frequencyFlag'],
      teacherNote: map['teacherNote'],
      aiAnalysisSummary: map['aiAnalysisSummary'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'game': game,
      'conductedBy': conductedBy,
      'conductorRole': conductorRole,
      'date': Timestamp.fromDate(date),
      'score': score,
      if (whisperTranscript != null) 'whisperTranscript': whisperTranscript,
      if (expectedWord != null) 'expectedWord': expectedWord,
      if (matchScore != null) 'matchScore': matchScore,
      if (clarityRating != null) 'clarityRating': clarityRating,
      if (phonemesMissed != null) 'phonemesMissed': phonemesMissed,
      if (lingResults != null) 'lingResults': lingResults,
      if (frequencyFlag != null) 'frequencyFlag': frequencyFlag,
      if (teacherNote != null) 'teacherNote': teacherNote,
      if (aiAnalysisSummary != null) 'aiAnalysisSummary': aiAnalysisSummary,
    };
  }
}
