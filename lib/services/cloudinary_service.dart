import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:heartech/core/constants/app_constants.dart';

/// Result of a Cloudinary upload attempt.
class UploadResult {
  final String? url;
  final String? errorMessage;

  const UploadResult({this.url, this.errorMessage});

  bool get isSuccess => url != null && url!.isNotEmpty;
}

/// Cloudinary upload service — replaces Firebase Storage (free tier).
class CloudinaryService {
  final Dio _dio = Dio();

  /// Upload a file to Cloudinary and return the URL.
  Future<UploadResult> uploadFile(File file, {String? folder}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': AppConstants.cloudinaryUploadPreset,
        if (folder != null) 'folder': folder,
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${AppConstants.cloudinaryCloudName}/auto/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        final url = response.data['secure_url'] as String?;
        if (url != null && url.isNotEmpty) {
          return UploadResult(url: url);
        }
        return const UploadResult(
          errorMessage: 'Upload failed — no URL returned from server.',
        );
      }
      return UploadResult(
        errorMessage: 'Upload failed — server returned ${response.statusCode}.',
      );
    } on DioException catch (e) {
      _logDioError('uploadFile', e);
      return UploadResult(errorMessage: _userMessageFromDio(e));
    } catch (e) {
      debugPrint('[CloudinaryService] uploadFile error: $e');
      return const UploadResult(
        errorMessage: 'Upload failed — check your internet connection.',
      );
    }
  }

  /// Upload a profile or document image (compression handled by ImagePicker).
  Future<UploadResult> uploadImage(File file, {String? folder}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': AppConstants.cloudinaryUploadPreset,
        if (folder != null) 'folder': folder,
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${AppConstants.cloudinaryCloudName}/image/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        final url = response.data['secure_url'] as String?;
        if (url != null && url.isNotEmpty) {
          return UploadResult(url: url);
        }
        return const UploadResult(
          errorMessage: 'Upload failed — no URL returned from server.',
        );
      }
      return UploadResult(
        errorMessage: 'Upload failed — server returned ${response.statusCode}.',
      );
    } on DioException catch (e) {
      _logDioError('uploadImage', e);
      return UploadResult(errorMessage: _userMessageFromDio(e));
    } catch (e) {
      debugPrint('[CloudinaryService] uploadImage error: $e');
      return const UploadResult(
        errorMessage: 'Upload failed — check your internet connection.',
      );
    }
  }

  /// Upload license or other documents (supports images and PDFs).
  Future<UploadResult> uploadLicenseDocument(File file, {String? folder}) {
    return uploadFile(file, folder: folder ?? 'heartech/licenses');
  }

  /// Upload audio file.
  Future<UploadResult> uploadAudio(File file, {String? folder}) {
    return uploadFile(file, folder: folder ?? 'heartech/audio');
  }

  void _logDioError(String method, DioException e) {
    final data = e.response?.data;
    debugPrint('[CloudinaryService] $method DioException: ${e.message}');
    if (data != null) {
      debugPrint('[CloudinaryService] response: $data');
    }
  }

  String _userMessageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = data['error']['message'];
      if (message is String && message.isNotEmpty) {
        return 'Upload failed — $message';
      }
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Upload failed — check your internet connection.';
    }
    return 'Upload failed — please try again.';
  }
}
