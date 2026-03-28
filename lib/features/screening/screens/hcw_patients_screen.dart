import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/child_card.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

/// HCW Patients list.
class HcwPatientsScreen extends ConsumerStatefulWidget {
  const HcwPatientsScreen({super.key});

  @override
  ConsumerState<HcwPatientsScreen> createState() => _HcwPatientsScreenState();
}

class _HcwPatientsScreenState extends ConsumerState<HcwPatientsScreen> {
  String _searchQuery = '';
  String _filterRisk = 'all'; // all, high, medium, low

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(hcwChildrenProvider);

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.hcwDashboard),
        ),
        title: Text('My Patients', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: HearTechColors.deepTeal,
        onPressed: () => context.go(Routes.hcwNewScreening),
        child: const Icon(Icons.add, color: HearTechColors.white),
      ),
      body: Column(
        children: [
          // Search & filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              children: [
                HearTechInputField(
                  label: 'Search patients...',
                  prefixIcon: Icons.search,
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: ['all', 'high', 'medium', 'low'].map((risk) {
                    final selected = _filterRisk == risk;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(risk == 'all' ? 'All' : risk[0].toUpperCase() + risk.substring(1)),
                        selected: selected,
                        selectedColor: risk == 'high'
                            ? HearTechColors.coralRed
                            : risk == 'medium'
                                ? HearTechColors.warmOrange
                                : risk == 'low'
                                    ? HearTechColors.green
                                    : HearTechColors.deepTeal,
                        labelStyle: TextStyle(
                          color: selected ? HearTechColors.white : HearTechColors.textPrimary,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                        onSelected: (_) => setState(() => _filterRisk = risk),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Patient list
          Expanded(
            child: childrenAsync.when(
              loading: () => const LoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (children) {
                var filtered = children.where((c) {
                  if (_filterRisk != 'all' && c.riskLevel != _filterRisk) return false;
                  if (_searchQuery.isNotEmpty && !c.name.toLowerCase().contains(_searchQuery)) return false;
                  return true;
                }).toList();

                filtered.sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: HearTechColors.textSecondary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('No patients found', style: HearTechTextStyles.subtitle()),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: filtered.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final child = filtered[index];
                    return ChildCard(
                      name: child.name,
                      ageString: child.ageString,
                      riskLevel: child.riskLevel,
                      riskScore: child.riskScore,
                      photoUrl: child.profilePhotoUrl,
                      showScore: true,
                      onTap: () => context.go(
                        Routes.hcwChildProfile.replaceFirst(':childId', child.childId),
                      ),
                    ).animate(delay: (index * 40).ms)
                        .fadeIn(duration: 200.ms)
                        .slideY(begin: 0.05, end: 0, duration: 200.ms);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
