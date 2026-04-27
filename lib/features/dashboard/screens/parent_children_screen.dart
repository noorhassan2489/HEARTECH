import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';

/// Parent "My Children" screen — dedicated list view of all linked children.
/// Accessible from bottom nav bar "Children" tab.
class ParentChildrenScreen extends ConsumerWidget {
  const ParentChildrenScreen({super.key});

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(Routes.parentDashboard); break;
      case 1: break; // already here
      case 2: context.go(Routes.parentSpeechGames); break;
      case 3: context.go(Routes.parentProfile); break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentChildrenProvider);

    return Scaffold(
      backgroundColor: HearTechColors.background,
      bottomNavigationBar: HearTechBottomNavBar(
        currentIndex: 1,
        onTap: (i) => _onNavTap(context, i),
        role: 'parent',
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('My Children', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: childrenAsync.when(
        loading: () => const LoadingIndicator(message: 'Loading children...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: HearTechColors.paleTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.family_restroom, size: 56, color: HearTechColors.deepTeal),
                    ),
                    const SizedBox(height: 20),
                    Text('No Children Linked', style: HearTechTextStyles.screenTitle()),
                    const SizedBox(height: 8),
                    Text(
                      'Enter a handover code from your healthcare worker to link your child\'s profile.',
                      style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    HearTechButton(
                      label: 'Enter Code',
                      icon: Icons.qr_code,
                      onPressed: () => context.go(Routes.parentClaimProfile),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: children.length,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final child = children[index];
              final lastScreening = child.lastScreeningDate;

              return GestureDetector(
                onTap: () => context.go(
                  Routes.parentChildProfile.replaceFirst(':childId', child.childId),
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HearTechColors.white,
                    borderRadius: HearTechDecorations.cardBorderRadius,
                    boxShadow: HearTechDecorations.cardShadow,
                  ),
                  child: Row(
                    children: [
                      AvatarCircle(name: child.name, photoUrl: child.profilePhotoUrl, radius: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(child.name, style: HearTechTextStyles.subtitle()),
                            const SizedBox(height: 2),
                            Text(child.ageString, style: HearTechTextStyles.caption()),
                            if (lastScreening != null)
                              Text(
                                'Last screening: ${DateFormat('d MMM yyyy').format(lastScreening)}',
                                style: HearTechTextStyles.caption(color: HearTechColors.textSecondary)
                                    .copyWith(fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      RiskBadge(riskLevel: child.riskLevel),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: HearTechColors.textSecondary),
                    ],
                  ),
                ),
              ).animate(delay: (index * 80).ms)
                  .fadeIn(duration: 250.ms)
                  .slideX(begin: -0.05, end: 0);
            },
          );
        },
      ),
    );
  }
}
