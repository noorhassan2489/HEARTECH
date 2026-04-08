import 'package:cloud_firestore/cloud_firestore.dart';

/// Clinical note — stored under /children/{childId}/notes/{noteId}
class NoteModel {
  final String noteId;
  final String authorUid;
  final String authorName;
  final String authorRole; // hcw, parent, teacher
  final String text;
  final bool isPublic; // visible to parent
  final bool isTeacherVisible; // visible to teacher
  final DateTime createdAt;

  const NoteModel({
    required this.noteId,
    required this.authorUid,
    required this.authorName,
    this.authorRole = 'hcw',
    required this.text,
    this.isPublic = false,
    this.isTeacherVisible = false,
    required this.createdAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      noteId: json['noteId'] as String? ?? '',
      authorUid: json['authorUid'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      authorRole: json['authorRole'] as String? ?? 'hcw',
      text: json['text'] as String? ?? '',
      isPublic: json['isPublic'] as bool? ?? false,
      isTeacherVisible: json['isTeacherVisible'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'noteId': noteId,
        'authorUid': authorUid,
        'authorName': authorName,
        'authorRole': authorRole,
        'text': text,
        'isPublic': isPublic,
        'isTeacherVisible': isTeacherVisible,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
