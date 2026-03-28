import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Circular avatar with photo or initials and gradient teal border.
class AvatarCircle extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool showBorder;

  const AvatarCircle({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);

    return Container(
      padding: showBorder ? const EdgeInsets.all(2) : null,
      decoration: showBorder
          ? const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [HearTechColors.deepTeal, HearTechColors.mediumTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: HearTechColors.paleTeal,
        backgroundImage:
            photoUrl != null && photoUrl!.isNotEmpty ? NetworkImage(photoUrl!) : null,
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(
                initials,
                style: HearTechTextStyles.button(
                  color: HearTechColors.deepTeal,
                ).copyWith(fontSize: radius * 0.7),
              )
            : null,
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
