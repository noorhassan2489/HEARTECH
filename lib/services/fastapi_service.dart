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

  /// Get current user UID from auth service.
  String? get _currentUid => _authService.currentUser?.uid;

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
    String? clinicalNote,
    Map<String, dynamic>? childMetadata,
  }) async {
    final response = await _dio.post('/api/risk-score', data: {
      'answers': answers,
      'ageBracket': ageBracket,
      'conductorRole': conductorRole,
      'childId': childId,
      if (clinicalNote != null) 'clinicalNote': clinicalNote,
      if (childMetadata != null) 'childMetadata': childMetadata,
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

  /// Claim a child profile using handover code. Sends parentUid.
  /// Handles DioException so error responses from the server are surfaced
  /// as Map data rather than thrown exceptions.
  Future<Map<String, dynamic>> claimProfile({
    required String code,
  }) async {
    try {
      final response = await _dio.post('/api/claim-profile', data: {
        'code': code.toUpperCase(),
        'parentUid': _currentUid,
      });
      return response.data;
    } on DioException catch (e) {
      // If the server returned a response body (e.g. {"error": "invalid"}),
      // surface it so the UI can read the error key.
      if (e.response?.data is Map<String, dynamic>) {
        return e.response!.data as Map<String, dynamic>;
      }
      return {'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> regenerateHandoverCode({
    required String childId,
    required String hcwUid,
  }) async {
    final response = await _dio.post('/api/regenerate-handover-code', data: {
      'childId': childId,
      'hcwUid': hcwUid,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Invite a teacher. Sends parentUid for authorization.
  Future<Map<String, dynamic>> inviteTeacher({
    required String childId,
    required String teacherEmail,
  }) async {
    final response = await _dio.post('/api/invite-teacher', data: {
      'childId': childId,
      'parentUid': _currentUid,
      'teacherEmail': teacherEmail,
    });
    return response.data;
  }

  /// Cancel a pending invite. Sends parentUid for authorization.
  Future<Map<String, dynamic>> cancelInvite({
    required String inviteId,
  }) async {
    final response = await _dio.post('/api/cancel-invite', data: {
      'inviteId': inviteId,
      'parentUid': _currentUid,
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
      'teacherUid': _currentUid,
    });
    return response.data;
  }

  /// Get pending invites. Can filter by teacherUid or parentUid.
  Future<List<dynamic>> getPendingInvites({String? parentUid}) async {
    final params = <String, dynamic>{};
    if (parentUid != null) {
      params['parentUid'] = parentUid;
    } else {
      // Default: use current user as teacher
      params['teacherUid'] = _currentUid;
    }
    final response = await _dio.get('/api/pending-invites', queryParameters: params);
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REMOVE LINKS — always through FastAPI, NOT direct Firestore
  // ═══════════════════════════════════════════════════════════════════════════

  /// Remove HCW from child. Sends parentUid for authorization.
  Future<Map<String, dynamic>> removeHcw({
    required String childId,
    required String hcwId,
  }) async {
    final response = await _dio.post('/api/remove-hcw', data: {
      'childId': childId,
      'parentUid': _currentUid,
      'hcwId': hcwId,
    });
    return response.data;
  }

  /// Remove teacher from child. Sends parentUid + teacherUid for authorization.
  Future<Map<String, dynamic>> removeTeacher({
    required String childId,
    required String teacherUid,
  }) async {
    final response = await _dio.post('/api/remove-teacher', data: {
      'childId': childId,
      'parentUid': _currentUid,
      'teacherUid': teacherUid,
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
