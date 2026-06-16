import 'dart:io';

import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/services/cloudinary_service.dart';

/// Shared Cloudinary upload helpers with consistent user feedback.
class MediaUpload {
  MediaUpload._();

  static Future<String?> uploadProfilePhoto({
    required BuildContext context,
    required CloudinaryService cloudinary,
    required File file,
  }) async {
    final result = await cloudinary.uploadImage(
      file,
      folder: 'heartech/profiles',
    );
    if (!context.mounted) return null;
    return _handleResult(
      context,
      result,
      successMessage: 'Photo uploaded!',
    );
  }

  static Future<String?> uploadLicenseDocument({
    required BuildContext context,
    required CloudinaryService cloudinary,
    required File file,
  }) async {
    final result = await cloudinary.uploadLicenseDocument(file);
    if (!context.mounted) return null;
    return _handleResult(
      context,
      result,
      successMessage: 'License uploaded!',
    );
  }

  static String? _handleResult(
    BuildContext context,
    UploadResult result, {
    required String successMessage,
  }) {
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: HearTechColors.green,
        ),
      );
      return result.url;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.errorMessage ?? 'Upload failed — tap to retry.'),
        backgroundColor: HearTechColors.coralRed,
      ),
    );
    return null;
  }
}

/// Green/red upload status row for registration flows.
class UploadStatusRow extends StatelessWidget {
  final bool hasLocalFile;
  final String? uploadedUrl;
  final String successLabel;
  final String failureLabel;

  const UploadStatusRow({
    super.key,
    required this.hasLocalFile,
    required this.uploadedUrl,
    this.successLabel = 'Uploaded successfully',
    this.failureLabel = 'Upload failed — tap to retry',
  });

  @override
  Widget build(BuildContext context) {
    if (uploadedUrl != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: HearTechColors.green, size: 16),
          const SizedBox(width: 4),
          Text(
            successLabel,
            style: HearTechTextStyles.caption(color: HearTechColors.green),
          ),
        ],
      );
    }

    if (hasLocalFile) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: HearTechColors.coralRed, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              failureLabel,
              style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
