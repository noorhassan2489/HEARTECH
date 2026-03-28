import 'package:cloud_firestore/cloud_firestore.dart';

/// Referral record — stored under /children/{childId}/referrals/{referralId}
class ReferralModel {
  final String referralId;
  final String generatedByHcwId;
  final DateTime generatedAt;
  final String? pdfCloudinaryUrl;
  final String? letterText;
  final String screeningId;

  const ReferralModel({
    required this.referralId,
    required this.generatedByHcwId,
    required this.generatedAt,
    this.pdfCloudinaryUrl,
    this.letterText,
    required this.screeningId,
  });

  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      referralId: json['referralId'] as String? ?? '',
      generatedByHcwId: json['generatedByHcwId'] as String? ?? '',
      generatedAt: _parseTimestamp(json['generatedAt']),
      pdfCloudinaryUrl: json['pdfCloudinaryUrl'] as String?,
      letterText: json['letterText'] as String?,
      screeningId: json['screeningId'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'referralId': referralId,
        'generatedByHcwId': generatedByHcwId,
        'generatedAt': Timestamp.fromDate(generatedAt),
        'pdfCloudinaryUrl': pdfCloudinaryUrl,
        'letterText': letterText,
        'screeningId': screeningId,
      };

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.parse(value);
    return DateTime.now();
  }
}
