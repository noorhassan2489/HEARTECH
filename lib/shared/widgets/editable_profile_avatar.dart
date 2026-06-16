import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/utils/media_upload.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';

/// Tap-to-change profile photo — uploads to Cloudinary and saves URL to Firestore.
class EditableProfileAvatar extends ConsumerStatefulWidget {
  final String uid;
  final String name;
  final String? photoUrl;
  final double radius;

  const EditableProfileAvatar({
    super.key,
    required this.uid,
    required this.name,
    this.photoUrl,
    this.radius = 50,
  });

  @override
  ConsumerState<EditableProfileAvatar> createState() =>
      _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends ConsumerState<EditableProfileAvatar> {
  bool _isUploading = false;
  String? _localPhotoUrl;

  String? get _displayUrl => _localPhotoUrl ?? widget.photoUrl;

  Future<void> _pickAndUpload() async {
    if (_isUploading) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploading = true);

    final cloudinary = ref.read(cloudinaryServiceProvider);
    final url = await MediaUpload.uploadProfilePhoto(
      context: context,
      cloudinary: cloudinary,
      file: File(picked.path),
    );

    if (!mounted) return;

    if (url != null) {
      await ref.read(firestoreServiceProvider).updateUser(widget.uid, {
        'profilePhotoUrl': url,
      });
      ref.invalidate(currentUserProfileProvider);
      setState(() {
        _localPhotoUrl = url;
        _isUploading = false;
      });
    } else {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickAndUpload,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AvatarCircle(
            name: widget.name,
            photoUrl: _displayUrl,
            radius: widget.radius,
          ),
          if (_isUploading)
            SizedBox(
              width: widget.radius * 2 + 4,
              height: widget.radius * 2 + 4,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(HearTechColors.deepTeal),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: HearTechColors.deepTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: HearTechColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
