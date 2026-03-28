import 'package:cloud_firestore/cloud_firestore.dart';

/// Speech log — stored under /children/{childId}/speechLogs/{logId}
class SpeechLogModel {
  final String logId;
  final String game; // showAndTell, lingSix
  final String conductedBy; // uid
  final String conductorRole; // parent, teacher
  final DateTime date;
  final int score; // 0-100

  // Show and Tell fields
  final String? whisperTranscript;
  final String? expectedWord;
  final int? matchScore;
  final String? clarityRating; // Excellent, Good, Needs Practice, Unclear
  final List<String>? phonemesMissed;

  // Ling Six fields
  final List<LingSixResult>? lingResults;
  final String? frequencyFlag;

  // Shared
  final String? teacherNote;
  final String? aiAnalysisSummary;

  const SpeechLogModel({
    required this.logId,
    required this.game,
    required this.conductedBy,
    required this.conductorRole,
    required this.date,
    this.score = 0,
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

  factory SpeechLogModel.fromJson(Map<String, dynamic> json) {
    return SpeechLogModel(
      logId: json['logId'] as String? ?? '',
      game: json['game'] as String? ?? '',
      conductedBy: json['conductedBy'] as String? ?? '',
      conductorRole: json['conductorRole'] as String? ?? '',
      date: _parseTimestamp(json['date']),
      score: json['score'] as int? ?? 0,
      whisperTranscript: json['whisperTranscript'] as String?,
      expectedWord: json['expectedWord'] as String?,
      matchScore: json['matchScore'] as int?,
      clarityRating: json['clarityRating'] as String?,
      phonemesMissed: json['phonemesMissed'] != null
          ? List<String>.from(json['phonemesMissed'])
          : null,
      lingResults: json['lingResults'] != null
          ? (json['lingResults'] as List<dynamic>)
              .map((r) =>
                  LingSixResult.fromJson(Map<String, dynamic>.from(r)))
              .toList()
          : null,
      frequencyFlag: json['frequencyFlag'] as String?,
      teacherNote: json['teacherNote'] as String?,
      aiAnalysisSummary: json['aiAnalysisSummary'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'logId': logId,
        'game': game,
        'conductedBy': conductedBy,
        'conductorRole': conductorRole,
        'date': Timestamp.fromDate(date),
        'score': score,
        'whisperTranscript': whisperTranscript,
        'expectedWord': expectedWord,
        'matchScore': matchScore,
        'clarityRating': clarityRating,
        'phonemesMissed': phonemesMissed,
        'lingResults': lingResults?.map((r) => r.toJson()).toList(),
        'frequencyFlag': frequencyFlag,
        'teacherNote': teacherNote,
        'aiAnalysisSummary': aiAnalysisSummary,
      };

  bool get isShowAndTell => game == 'showAndTell';
  bool get isLingSix => game == 'lingSix';

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

/// Single Ling Six sound result.
class LingSixResult {
  final String sound; // m, ah, oo, ee, sh, s
  final bool heard;

  const LingSixResult({required this.sound, required this.heard});

  factory LingSixResult.fromJson(Map<String, dynamic> json) {
    return LingSixResult(
      sound: json['sound'] as String? ?? '',
      heard: json['heard'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {'sound': sound, 'heard': heard};
}
