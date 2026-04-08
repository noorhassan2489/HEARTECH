import 'package:dio/dio.dart';
import 'package:heartech/core/constants/app_constants.dart';
import 'package:heartech/services/firebase_auth_service.dart';

/// FastAPI HTTP client with JWT auth interceptor.
class FastApiService {
  late final Dio _dio;
  final FirebaseAuthService _authService;

  FastApiService(this._authService) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.fastApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // JWT auth interceptor — attaches Firebase token to every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEALTH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AGE BRACKET
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getAgeBracket(String dob) async {
    final response = await _dio.get('/api/age-bracket/$dob');
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RISK SCORING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> calculateRiskScore({
    required List<Map<String, dynamic>> answers,
    required int ageBracket,
    required String conductorRole,
    String? childId,
  }) async {
    final response = await _dio.post('/api/risk-score', data: {
      'answers': answers,
      'ageBracket': ageBracket,
      'conductorRole': conductorRole,
      'childId': childId,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFERRALS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> generateReferral({
    required String childId,
    required String screeningId,
    required int riskScore,
    required List<Map<String, dynamic>> answers,
    required String hcwDescription,
    required Map<String, dynamic> hcwInfo,
    required Map<String, dynamic> childInfo,
  }) async {
    final response = await _dio.post('/api/generate-referral', data: {
      'childId': childId,
      'screeningId': screeningId,
      'riskScore': riskScore,
      'answers': answers,
      'hcwDescription': hcwDescription,
      'hcwInfo': hcwInfo,
      'childInfo': childInfo,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> generateReferralPdf({
    required String childId,
    required String referralId,
    required String referralText,
    required Map<String, dynamic> hcwInfo,
    required Map<String, dynamic> childInfo,
  }) async {
    final response = await _dio.post('/api/generate-referral-pdf', data: {
      'childId': childId,
      'referralId': referralId,
      'referralText': referralText,
      'hcwInfo': hcwInfo,
      'childInfo': childInfo,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HANDOVER CODE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> claimProfile({
    required String code,
  }) async {
    final response = await _dio.post('/api/claim-profile', data: {
      'code': code,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> regenerateHandoverCode({
    required String childId,
  }) async {
    final response = await _dio.post('/api/regenerate-handover-code', data: {
      'childId': childId,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> inviteTeacher({
    required String childId,
    required String teacherEmail,
  }) async {
    final response = await _dio.post('/api/invite-teacher', data: {
      'childId': childId,
      'teacherEmail': teacherEmail,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> cancelInvite({
    required String inviteId,
  }) async {
    final response = await _dio.post('/api/cancel-invite', data: {
      'inviteId': inviteId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> respondInvite({
    required String inviteId,
    required String action, // "accept" or "decline"
  }) async {
    final response = await _dio.post('/api/respond-invite', data: {
      'inviteId': inviteId,
      'action': action,
    });
    return response.data;
  }

  Future<List<dynamic>> getPendingInvites() async {
    final response = await _dio.get('/api/pending-invites');
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REMOVE LINKS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> removeHcw({
    required String childId,
    required String hcwId,
  }) async {
    final response = await _dio.post('/api/remove-hcw', data: {
      'childId': childId,
      'hcwId': hcwId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> removeTeacher({
    required String childId,
  }) async {
    final response = await _dio.post('/api/remove-teacher', data: {
      'childId': childId,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SPEECH
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> analyzeSpeech({
    required String audioFilePath,
    required String expectedWord,
    required String childId,
  }) async {
    final formData = FormData.fromMap({
      'audioFile': await MultipartFile.fromFile(audioFilePath),
      'expectedWord': expectedWord,
      'childId': childId,
    });
    final response = await _dio.post('/api/analyze-speech', data: formData);
    return response.data;
  }

  Future<Map<String, dynamic>> analyzeLingSix({
    required List<Map<String, dynamic>> results,
    required String childId,
  }) async {
    final response = await _dio.post('/api/ling-six-analysis', data: {
      'results': results,
      'childId': childId,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUESTIONNAIRES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getQuestionnaire({
    required String role,
    required int bracketId,
  }) async {
    final response = await _dio.get('/api/questionnaire/$role/$bracketId');
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUDINARY SIGNATURE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCloudinarySignature() async {
    final response = await _dio.post('/api/cloudinary-signature');
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> sendNotification({
    required String uid,
    required String type,
    required String title,
    required String body,
    String? priority,
    String? navigationRoute,
    String? relatedChildId,
  }) async {
    await _dio.post('/api/notifications/send', data: {
      'uid': uid,
      'type': type,
      'title': title,
      'body': body,
      if (priority != null) 'priority': priority,
      if (navigationRoute != null) 'navigationRoute': navigationRoute,
      if (relatedChildId != null) 'relatedChildId': relatedChildId,
    });
  }
}
