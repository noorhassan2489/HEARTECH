import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Recalculate combined milestone risk from all assessment sources.
  Future<Map<String, dynamic>> aggregateRiskScore({
    required String childId,
    String? trigger,
  }) async {
    final response = await _dio.post('/api/risk-score/aggregate', data: {
      'childId': childId,
      if (trigger != null) 'trigger': trigger,
    });
    return response.data;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REFERRALS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generate referral letter via AI chat — takes child data and HCW instruction.
  /// Uses extended receiveTimeout since runtime inference can take 60–180s.
  Future<Map<String, dynamic>> generateReferralChat({
    required Map<String, dynamic> childData,
    required String hcwInstruction,
  }) async {
    final response = await _dio.post(
      '/api/generate-referral-chat',
      data: {
        'childData': childData,
        'hcwInstruction': hcwInstruction,
      },
      options: Options(
        receiveTimeout: const Duration(seconds: 180),
      ),
    );
    return response.data;
  }

  /// Export referral text as PDF and upload to Cloudinary.
  Future<Map<String, dynamic>> exportReferralPdf({
    required String referralText,
    required String childName,
    required String childId,
  }) async {
    final response = await _dio.post('/api/export-referral-pdf', data: {
      'referralText': referralText,
      'childName': childName,
      'childId': childId,
    });
    return response.data;
  }

  /// Export referral text as DOCX and upload to Cloudinary.
  Future<Map<String, dynamic>> exportReferralDocx({
    required String referralText,
    required String childName,
    required String childId,
  }) async {
    final response = await _dio.post('/api/export-referral-docx', data: {
      'referralText': referralText,
      'childName': childName,
      'childId': childId,
    });
    return response.data;
  }

  /// Download an export file (local server or Cloudinary URL) into app temp storage.
  Future<String> downloadExportToTemp({
    required String fileUrl,
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await _dio.download(fileUrl, path);
    return path;
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

  /// Invite an HCW to a parent-linked child profile.
  Future<Map<String, dynamic>> inviteHcw({
    required String childId,
    required String hcwEmail,
  }) async {
    final response = await _dio.post('/api/invite-hcw', data: {
      'childId': childId,
      'parentUid': _currentUid,
      'hcwEmail': hcwEmail,
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
    String inviteType = 'teacher',
  }) async {
    final response = await _dio.post('/api/respond-invite', data: {
      'inviteId': inviteId,
      'action': action,
      if (inviteType == 'hcw') 'hcwUid': _currentUid else 'teacherUid': _currentUid,
    });
    return response.data;
  }

  /// Get pending invites. Can filter by teacherUid, hcwUid, or parentUid.
  Future<List<dynamic>> getPendingInvites({
    String? parentUid,
    String inviteeRole = 'teacher',
  }) async {
    final params = <String, dynamic>{};
    if (parentUid != null) {
      params['parentUid'] = parentUid;
    } else if (inviteeRole == 'hcw') {
      params['hcwUid'] = _currentUid;
    } else {
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

  /// HCW removes themselves from a parent-linked child profile.
  Future<Map<String, dynamic>> hcwUnlinkSelf({
    required String childId,
  }) async {
    final uid = _currentUid;
    final response = await _dio.post('/api/remove-hcw', data: {
      'childId': childId,
      'parentUid': uid,
      'hcwId': uid,
    });
    return response.data;
  }

  /// Permanently delete an unclaimed child profile (HCW only).
  Future<Map<String, dynamic>> hcwDeleteChild({
    required String childId,
  }) async {
    final response = await _dio.post('/api/hcw-delete-child', data: {
      'childId': childId,
      'hcwUid': _currentUid,
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

  /// Fetch Show and Tell image URLs organized by category.
  Future<Map<String, dynamic>> getSpeechImages() async {
    final response = await _dio.get('/api/speech-images');
    return Map<String, dynamic>.from(response.data);
  }

  /// Fetch Ling Six audio/image manifest from Cloudinary via backend.
  Future<Map<String, dynamic>> getLingSixAssets() async {
    final response = await _dio.get('/api/ling-six-assets');
    return Map<String, dynamic>.from(response.data);
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

  /// Plain-language API error for snackbars (physical device + localhost is common).
  static String userFacingMessage(Object error) {
    if (error is DioException) {
      final isConnection = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout;
      if (isConnection) {
        final base = AppConstants.fastApiBaseUrl;
        if (base.contains('127.0.0.1') || base.contains('localhost')) {
          return 'Cannot reach the screening server. On a physical phone, '
              'run the backend on your Mac with --host 0.0.0.0 --port 8000, '
              'then restart the app with '
              '--dart-define=FASTAPI_BASE_URL=http://YOUR_MAC_WIFI_IP:8000';
        }
        return 'Cannot reach the screening server at $base. '
            'Check that the backend is running and your phone is on the same Wi‑Fi.';
      }
      final detail = error.response?.data;
      if (detail is Map && detail['detail'] != null) {
        return detail['detail'].toString();
      }
    }
    return error.toString();
  }
}
