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

  static const showAndTellGame = 'showAndTell';
  static const lingSixGame = 'lingSix';

  /// Canonicalize legacy/alternate game ids from Firestore or older builds.
  static String normalizeGame(String? raw) {
    final compact = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_-]+'), '');
    switch (compact) {
      case 'showandtell':
        return showAndTellGame;
      case 'lingsix':
        return lingSixGame;
      default:
        return (raw ?? '').trim();
    }
  }

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
      game: normalizeGame(json['game'] as String?),
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
        'game': normalizeGame(game),
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

  bool get isShowAndTell => normalizeGame(game) == showAndTellGame;
  bool get isLingSix => normalizeGame(game) == lingSixGame;

  String get gameDisplayName {
    if (isShowAndTell) return 'Show & Tell';
    if (isLingSix) return 'Ling Six';
    return game.isEmpty ? 'Speech Session' : game;
  }

  static bool isShowAndTellGame(String? raw) => normalizeGame(raw) == showAndTellGame;
  static bool isLingSixGame(String? raw) => normalizeGame(raw) == lingSixGame;
  static String displayNameFor(String? raw) {
    if (isShowAndTellGame(raw)) return 'Show & Tell';
    if (isLingSixGame(raw)) return 'Ling Six';
    final value = (raw ?? '').trim();
    return value.isEmpty ? 'Speech Session' : value;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}

/// Single Ling Six sound result — supports two-round testing.
class LingSixResult {
  final String sound; // m, ah, oo, ee, sh, s
  final bool round1heard;
  final bool round2heard;

  // Backward compatibility: single `heard` maps to round1heard
  bool get heard => round1heard;

  const LingSixResult({
    required this.sound,
    this.round1heard = false,
    this.round2heard = false,
  });

  factory LingSixResult.fromJson(Map<String, dynamic> json) {
    return LingSixResult(
      sound: json['sound'] as String? ?? '',
      round1heard: json['round1heard'] as bool? ?? json['heard'] as bool? ?? false,
      round2heard: json['round2heard'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'sound': sound,
        'round1heard': round1heard,
        'round2heard': round2heard,
      };
}
