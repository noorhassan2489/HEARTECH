import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/child_card.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/widgets/empty_state_card.dart';

/// Teacher My Class — list of all linked students.
class MyClassScreen extends ConsumerWidget {
  const MyClassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(teacherChildrenProvider);

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.teacherDashboard),
        ),
        title: Text('My Class', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: childrenAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (children) {
          if (children.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: EmptyStateCard(
                icon: Icons.school_outlined,
                title: 'No students yet',
                subtitle: 'Accept invites from parents to see your students here.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: children.length,
            separatorBuilder: (_, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final child = children[index];
              return ChildCard(
                name: child.name,
                ageString: child.ageString,
                riskLevel: child.riskLevel,
                photoUrl: child.profilePhotoUrl,
                onTap: () => context.go(
                  Routes.teacherChildProfile.replaceFirst(':childId', child.childId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
