import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class FastApiService {
  FastApiService._();

  // Use 10.0.2.2 for Android emulator, or localhost for iOS simulator/web
  static const String _baseUrl = 'http://localhost:8080/api';
  
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ))..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));

  // Risk Scoring
  static Future<Map<String, dynamic>> calculateRiskScore(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/risk-score', data: data);
      return response.data;
    } catch (e) {
      throw Exception('Failed to calculate risk score: $e');
    }
  }

  // AI Referral Generation
  static Future<String> generateReferral(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/generate-referral', data: data);
      return response.data['referral_text'];
    } catch (e) {
      throw Exception('Failed to generate referral: $e');
    }
  }

  // Speech Analysis (Whisper)
  static Future<Map<String, dynamic>> analyzeSpeech(String audioFilePath, String targetWord) async {
    try {
      final file = File(audioFilePath);
      String fileName = file.path.split('/').last;

      FormData formData = FormData.fromMap({
        "audio": await MultipartFile.fromFile(file.path, filename: fileName),
        "target_word": targetWord,
      });

      final response = await _dio.post('/analyze-speech', data: formData);
      return response.data;
    } catch (e) {
      throw Exception('Failed to analyze speech: $e');
    }
  }

  // Ling Six Analysis
  static Future<Map<String, dynamic>> analyzeLingSix(Map<String, bool> responses, double distance) async {
    try {
      final data = {
        "responses": responses,
        "distance_meters": distance,
      };
      final response = await _dio.post('/ling-six-analysis', data: data);
      return response.data;
    } catch (e) {
      throw Exception('Failed to analyze Ling Six responses: $e');
    }
  }
}
