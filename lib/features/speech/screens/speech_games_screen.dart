import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/child_card.dart';

/// Speech Games Hub — shows available games and child selection.
class SpeechGamesScreen extends ConsumerWidget {
  const SpeechGamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentChildrenProvider);

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text('Speech Games', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game cards
            _GameCard(
              icon: Icons.mic,
              title: 'Show & Tell',
              description: 'Whisper a word and record your child\'s response to assess speech clarity.',
              color: HearTechColors.deepTeal,
              onSelect: (childId) => context.go(Routes.showAndTell.replaceFirst(':childId', childId)),
            ),
            const SizedBox(height: 16),
            _GameCard(
              icon: Icons.hearing,
              title: 'Ling Six Test',
              description: 'Test your child\'s ability to hear 6 key speech sounds across frequencies.',
              color: HearTechColors.purple,
              onSelect: (childId) => context.go(Routes.lingSix.replaceFirst(':childId', childId)),
            ),
            const SizedBox(height: 32),

            // Child selection
            Text('Select a Child', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 12),
            childrenAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (children) {
                if (children.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: HearTechDecorations.cardDecoration,
                    child: Column(children: [
                      Icon(Icons.child_care, size: 48,
                          color: HearTechColors.deepTeal.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text('No children linked', style: HearTechTextStyles.subtitle()),
                      const SizedBox(height: 4),
                      Text('Claim a child profile first to play speech games.',
                          style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
                    ]),
                  );
                }

                return Column(
                  children: children.map((child) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ChildCard(
                      name: child.name,
                      ageString: child.ageString,
                      riskLevel: child.riskLevel,
                      photoUrl: child.profilePhotoUrl,
                      onTap: () {
                        // Store selected child for game navigation
                        _showGamePicker(context, child.childId);
                      },
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGamePicker(BuildContext context, String childId) {
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
            Text('Choose a Game', style: HearTechTextStyles.sectionHeader()),
            const SizedBox(height: 20),
            HearTechButton(
              label: '🎤  Show & Tell',
              onPressed: () {
                Navigator.pop(ctx);
                context.go(Routes.showAndTell.replaceFirst(':childId', childId));
              },
            ),
            const SizedBox(height: 12),
            HearTechButton(
              label: '👂  Ling Six Test',
              onPressed: () {
                Navigator.pop(ctx);
                context.go(Routes.lingSix.replaceFirst(':childId', childId));
              },
              isSecondary: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final void Function(String childId) onSelect;

  const _GameCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: HearTechDecorations.cardBorderRadius,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HearTechColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 28, color: HearTechColors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: HearTechTextStyles.subtitle(color: HearTechColors.white)),
                const SizedBox(height: 4),
                Text(description,
                    style: HearTechTextStyles.caption(color: HearTechColors.white.withValues(alpha: 0.8)),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
