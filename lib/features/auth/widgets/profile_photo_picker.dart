import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

class ProfilePhotoPicker extends StatefulWidget {
  final Function(File?) onImageSelected;
  final String? initialImageUrl;

  const ProfilePhotoPicker({
    super.key,
    required this.onImageSelected,
    this.initialImageUrl,
  });

  @override
  State<ProfilePhotoPicker> createState() => _ProfilePhotoPickerState();
}

class _ProfilePhotoPickerState extends State<ProfilePhotoPicker> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        final File file = File(image.path);
        setState(() => _selectedImage = file);
        widget.onImageSelected(file);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.primaryTeal),
                title: const Text('Photo Library'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera, color: AppTheme.primaryTeal),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
              if (_selectedImage != null || widget.initialImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: AppTheme.accentCoral),
                  title: const Text('Remove Photo', style: TextStyle(color: AppTheme.accentCoral)),
                  onTap: () {
                    setState(() => _selectedImage = null);
                    widget.onImageSelected(null);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _showPickerOptions,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryTeal, width: 2),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : (widget.initialImageUrl != null)
                        ? DecorationImage(
                            image: NetworkImage(widget.initialImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
              ),
              child: _selectedImage == null && widget.initialImageUrl == null
                  ? const Icon(Icons.person, size: 60, color: AppTheme.primaryTeal)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
