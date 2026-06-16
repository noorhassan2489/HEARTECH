import 'package:cloud_firestore/cloud_firestore.dart';

/// Referral lifecycle status.
enum ReferralStatus {
  draft,
  discarded,
  finalized;

  static ReferralStatus fromString(String? value) {
    switch (value) {
      case 'discarded':
        return ReferralStatus.discarded;
      case 'finalized':
        return ReferralStatus.finalized;
      default:
        return ReferralStatus.draft;
    }
  }

  String get firestoreValue => name;
}

/// Referral record — stored under /children/{childId}/referrals/{referralId}
class ReferralModel {
  final String referralId;
  final String generatedByHcwId;
  final DateTime generatedAt;
  final String? pdfCloudinaryUrl;
  final String? letterText;
  final String screeningId;
  final ReferralStatus status;
  final String? parentId;
  final bool isVisibleToParent;
  final bool isVisibleToTeacher;
  final List<String> visibleToTeacherIds;
  final DateTime? finalizedAt;
  final String? title;

  const ReferralModel({
    required this.referralId,
    required this.generatedByHcwId,
    required this.generatedAt,
    this.pdfCloudinaryUrl,
    this.letterText,
    required this.screeningId,
    this.status = ReferralStatus.draft,
    this.parentId,
    this.isVisibleToParent = false,
    this.isVisibleToTeacher = false,
    this.visibleToTeacherIds = const [],
    this.finalizedAt,
    this.title,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      referralId: json['referralId'] as String? ?? '',
      generatedByHcwId: json['generatedByHcwId'] as String? ?? '',
      generatedAt: _parseTimestamp(json['generatedAt']),
      pdfCloudinaryUrl: json['pdfCloudinaryUrl'] as String?,
      letterText: json['letterText'] as String?,
      screeningId: json['screeningId'] as String? ?? '',
      status: ReferralStatus.fromString(json['status'] as String?),
      parentId: json['parentId'] as String?,
      isVisibleToParent: json['isVisibleToParent'] as bool? ?? false,
      isVisibleToTeacher: json['isVisibleToTeacher'] as bool? ?? false,
      visibleToTeacherIds:
          List<String>.from(json['visibleToTeacherIds'] ?? const []),
      finalizedAt: json['finalizedAt'] != null
          ? _parseTimestamp(json['finalizedAt'])
          : null,
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'referralId': referralId,
        'generatedByHcwId': generatedByHcwId,
        'generatedAt': Timestamp.fromDate(generatedAt),
        if (pdfCloudinaryUrl != null) 'pdfCloudinaryUrl': pdfCloudinaryUrl,
        if (letterText != null) 'letterText': letterText,
        'screeningId': screeningId,
        'status': status.firestoreValue,
        if (parentId != null && parentId!.isNotEmpty) 'parentId': parentId,
        'isVisibleToParent': isVisibleToParent,
        'isVisibleToTeacher': isVisibleToTeacher,
        if (visibleToTeacherIds.isNotEmpty)
          'visibleToTeacherIds': visibleToTeacherIds,
        if (finalizedAt != null)
          'finalizedAt': Timestamp.fromDate(finalizedAt!),
        if (title != null && title!.isNotEmpty) 'title': title,
      };

  ReferralModel copyWith({
    String? pdfCloudinaryUrl,
    String? letterText,
    ReferralStatus? status,
    String? parentId,
    bool? isVisibleToParent,
    bool? isVisibleToTeacher,
    List<String>? visibleToTeacherIds,
    DateTime? finalizedAt,
    String? title,
  }) {
    return ReferralModel(
      referralId: referralId,
      generatedByHcwId: generatedByHcwId,
      generatedAt: generatedAt,
      pdfCloudinaryUrl: pdfCloudinaryUrl ?? this.pdfCloudinaryUrl,
      letterText: letterText ?? this.letterText,
      screeningId: screeningId,
      status: status ?? this.status,
      parentId: parentId ?? this.parentId,
      isVisibleToParent: isVisibleToParent ?? this.isVisibleToParent,
      isVisibleToTeacher: isVisibleToTeacher ?? this.isVisibleToTeacher,
      visibleToTeacherIds: visibleToTeacherIds ?? this.visibleToTeacherIds,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      title: title ?? this.title,
    );
  }

  /// Short label for list cards from letter text.
  static String titleFromLetter(String? letterText) {
    if (letterText == null || letterText.trim().isEmpty) {
      return 'Referral draft';
    }
    for (final line in letterText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.toUpperCase().startsWith('CLINICAL SUMMARY')) continue;
      if (trimmed == 'PATIENT REFERRAL' || trimmed.startsWith('─')) continue;
      if (trimmed.length > 80) return '${trimmed.substring(0, 80)}...';
      return trimmed;
    }
    return 'Referral draft';
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
