import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/utils/media_upload.dart';

/// Settings tile to upload or replace an HCW license document.
class LicenseDocumentUploadTile extends ConsumerStatefulWidget {
  final String uid;

  const LicenseDocumentUploadTile({super.key, required this.uid});

  @override
  ConsumerState<LicenseDocumentUploadTile> createState() =>
      _LicenseDocumentUploadTileState();
}

class _LicenseDocumentUploadTileState
    extends ConsumerState<LicenseDocumentUploadTile> {
  bool _isUploading = false;

  Future<void> _uploadLicense() async {
    if (_isUploading) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);

    final cloudinary = ref.read(cloudinaryServiceProvider);
    final url = await MediaUpload.uploadLicenseDocument(
      context: context,
      cloudinary: cloudinary,
      file: File(picked.path),
    );

    if (!mounted) return;

    if (url != null) {
      await ref.read(firestoreServiceProvider).updateUser(widget.uid, {
        'licenseDocUrl': url,
      });
      ref.invalidate(currentUserProfileProvider);
    }

    if (mounted) setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _isUploading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file, color: HearTechColors.deepTeal),
      title: Text(
        _isUploading ? 'Uploading license...' : 'Upload / Update License',
        style: HearTechTextStyles.body(),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: HearTechColors.textSecondary,
      ),
      onTap: _isUploading ? null : _uploadLicense,
    );
  }
}
