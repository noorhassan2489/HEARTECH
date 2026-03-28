import 'dart:io';
import 'package:dio/dio.dart';
import 'package:heartech/core/constants/app_constants.dart';

/// Cloudinary upload service — replaces Firebase Storage (free tier).
class CloudinaryService {
  final Dio _dio = Dio();

  /// Upload a file to Cloudinary and return the URL.
  Future<String?> uploadFile(File file, {String? folder}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': AppConstants.cloudinaryUploadPreset,
        if (folder != null) 'folder': folder, // ignore: use_null_aware_elements
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${AppConstants.cloudinaryCloudName}/auto/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload image with compression.
  Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': AppConstants.cloudinaryUploadPreset,
        'folder': folder ?? 'heartech/images',
        'transformation': 'c_limit,w_800,h_800,q_80',
      });

      final response = await _dio.post(
        'https://api.cloudinary.com/v1_1/${AppConstants.cloudinaryCloudName}/image/upload',
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Upload audio file.
  Future<String?> uploadAudio(File file, {String? folder}) async {
    return uploadFile(file, folder: folder ?? 'heartech/audio');
  }
}
