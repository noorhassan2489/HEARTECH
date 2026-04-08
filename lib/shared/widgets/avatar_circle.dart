import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Circular avatar — shows image with gradient border if URL exists,
/// or initials in a teal circle if no photo.
class AvatarCircle extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final bool showBorder;

  /// [radius] is a legacy alias for half of [size].
  /// New code should use [size]. Existing code using [radius] still works.
  const AvatarCircle({
    super.key,
    this.photoUrl,
    required this.name,
    double? radius,
    double? size,
    this.showBorder = true,
  }) : size = size ?? (radius != null ? radius * 2 : 48);

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final r = size / 2;
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    // Show gradient border when there is a photo
    if (hasPhoto && showBorder) {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: r,
            backgroundColor: HearTechColors.paleTeal,
            backgroundImage: NetworkImage(photoUrl!),
          ),
        ),
      );
    }

    // Initials fallback — teal circle with white text
    return CircleAvatar(
      radius: r,
      backgroundColor: HearTechColors.deepTeal,
      child: Text(
        initials,
        style: HearTechTextStyles.button(
          color: HearTechColors.white,
        ).copyWith(fontSize: r * 0.7),
      ),
    );
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '?';
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
