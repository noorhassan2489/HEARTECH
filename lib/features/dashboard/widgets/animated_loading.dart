// Mock animated loading if it wasn't made yet
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AnimatedLoading extends StatelessWidget {
  const AnimatedLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: AppTheme.primaryTeal),
    );
  }
}
