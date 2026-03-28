import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralModel {
  final String referralId;
  final String generatedByHcwId;
  final DateTime generatedAt;
  final String pdfCloudinaryUrl;
  final String letterText;
  final String status; // 'draft' | 'saved' | 'shared'
  final String? screeningId;

  ReferralModel({
    required this.referralId,
    required this.generatedByHcwId,
    required this.generatedAt,
    required this.pdfCloudinaryUrl,
    required this.letterText,
    required this.status,
    this.screeningId,
  });

  factory ReferralModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReferralModel(
      referralId: documentId,
      generatedByHcwId: map['generatedByHcwId'] ?? '',
      generatedAt: (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pdfCloudinaryUrl: map['pdfCloudinaryUrl'] ?? '',
      letterText: map['letterText'] ?? '',
      status: map['status'] ?? 'saved',
      screeningId: map['screeningId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'generatedByHcwId': generatedByHcwId,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'pdfCloudinaryUrl': pdfCloudinaryUrl,
      'letterText': letterText,
      'status': status,
      if (screeningId != null) 'screeningId': screeningId,
    };
  }
}
