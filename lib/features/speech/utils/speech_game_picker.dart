import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Bottom sheet to pick Show & Tell or Ling Six for a child speech session.
void showSpeechGamePicker(BuildContext context, String childId) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Speech Game', style: HearTechTextStyles.sectionHeader()),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.record_voice_over, color: HearTechColors.deepTeal),
            ),
            title: Text('Show and Tell', style: HearTechTextStyles.subtitle()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.showAndTell.replaceFirst(':childId', childId));
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HearTechColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hearing, color: HearTechColors.purple),
            ),
            title: Text('Ling Six Test', style: HearTechTextStyles.subtitle()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pop(ctx);
              context.push(Routes.lingSix.replaceFirst(':childId', childId));
            },
          ),
        ],
      ),
    ),
  );
}
