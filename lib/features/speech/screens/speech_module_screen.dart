import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SpeechModuleScreen extends StatelessWidget {
  final String childId;
  const SpeechModuleScreen({super.key, required this.childId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Speech Modules', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Interactive Assessments',
              style: AppTheme.heading1,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a speech module below to begin assessing the child\'s hearing and speech response.',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            
            _buildModuleCard(
              context,
              title: 'Show & Tell',
              description: 'Examine speech clarity through picture descriptions. Powered by AI.',
              icon: Icons.record_voice_over,
              color: AppTheme.primaryTeal,
              onTap: () => context.push(AppRouter.showAndTell, extra: {'childId': childId}),
            ),
            const SizedBox(height: 16),
            
            _buildModuleCard(
              context,
              title: 'Ling Six Sound Test',
              description: 'Check behavioral response to the six fundamental speech frequencies.',
              icon: Icons.hearing,
              color: AppTheme.accentCoral,
              onTap: () => context.push(AppRouter.lingSix, extra: {'childId': childId}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, {required String title, required String description, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.heading2),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
