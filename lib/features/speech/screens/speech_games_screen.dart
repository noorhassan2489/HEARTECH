import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

/// Speech Games Hub — child selection then game cards.
class SpeechGamesScreen extends ConsumerStatefulWidget {
  const SpeechGamesScreen({super.key});
  @override
  ConsumerState<SpeechGamesScreen> createState() => _SpeechGamesScreenState();
}

class _SpeechGamesScreenState extends ConsumerState<SpeechGamesScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider) ?? 'parent';
    final childrenAsync = role == 'teacher'
        ? ref.watch(teacherChildrenProvider)
        : ref.watch(parentChildrenProvider);

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: HearTechColors.deepTeal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('Speech Exercises',
            style: HearTechTextStyles.appBarTitle(color: HearTechColors.white)),
        centerTitle: true,
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (children) {
          if (children.isEmpty) return _buildEmpty();

          // Auto-select if only one child
          if (children.length == 1 && _selectedChildId == null) {
            _selectedChildId = children.first.childId;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Child selection (if multiple)
              if (children.length > 1) ...[
                Text('Select a Child', style: HearTechTextStyles.sectionHeader()),
                const SizedBox(height: 12),
                ...children.map((child) {
                  final selected = _selectedChildId == child.childId;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedChildId = child.childId;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? HearTechColors.deepTeal.withValues(alpha: 0.08) : HearTechColors.white,
                        borderRadius: HearTechDecorations.cardBorderRadius,
                        border: Border.all(
                          color: selected ? HearTechColors.deepTeal : HearTechColors.divider,
                          width: selected ? 2 : 1),
                        boxShadow: HearTechDecorations.subtleShadow,
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 20, backgroundColor: HearTechColors.paleTeal,
                          child: Text(child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                            style: HearTechTextStyles.subtitle(color: HearTechColors.deepTeal)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(child.name, style: HearTechTextStyles.subtitle(
                            color: selected ? HearTechColors.deepTeal : HearTechColors.textPrimary)),
                          Text(child.ageString, style: HearTechTextStyles.caption()),
                        ])),
                        if (selected) const Icon(Icons.check_circle, color: HearTechColors.deepTeal),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],

              if (_selectedChildId != null) ...[
                if (children.length > 1) ...[
                  Text('Choose a Game', style: HearTechTextStyles.sectionHeader()),
                  const SizedBox(height: 12),
                ],
                // Show and Tell Card
                _buildGameCard(
                  icon: Icons.record_voice_over,
                  title: 'Show and Tell',
                  description: 'Your child describes images to practice pronunciation',
                  color: HearTechColors.deepTeal,
                  buttonLabel: 'Play',
                  isPrimary: true,
                  onPressed: () => context.go(
                    Routes.showAndTell.replaceFirst(':childId', _selectedChildId!)),
                ),
                const SizedBox(height: 16),
                // Ling Six Card
                _buildGameCard(
                  icon: Icons.hearing,
                  title: 'Ling Six Sound Test',
                  description: 'Test your child\'s response to 6 key speech frequencies',
                  color: HearTechColors.purple,
                  buttonLabel: 'Start Test',
                  isPrimary: false,
                  onPressed: () => context.go(
                    Routes.lingSix.replaceFirst(':childId', _selectedChildId!)),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _buildGameCard({
    required IconData icon, required String title, required String description,
    required Color color, required String buttonLabel, required bool isPrimary,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: HearTechColors.white,
        borderRadius: HearTechDecorations.cardBorderRadius,
        boxShadow: HearTechDecorations.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, size: 32, color: color),
        ),
        const SizedBox(height: 16),
        Text(title, style: HearTechTextStyles.sectionHeader(color: color)
            .copyWith(fontSize: 20)),
        const SizedBox(height: 6),
        Text(description, style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
        const SizedBox(height: 16),
        HearTechButton(
          label: buttonLabel,
          isSecondary: !isPrimary,
          onPressed: onPressed,
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05);
  }

  Widget _buildEmpty() {
    return Center(child: Container(
      margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(24),
      decoration: HearTechDecorations.cardDecoration,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.child_care, size: 48, color: HearTechColors.deepTeal.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('No children linked', style: HearTechTextStyles.subtitle()),
        const SizedBox(height: 4),
        Text('Claim a child profile first to play speech games.',
          style: HearTechTextStyles.caption(), textAlign: TextAlign.center),
      ]),
    ));
  }
}
