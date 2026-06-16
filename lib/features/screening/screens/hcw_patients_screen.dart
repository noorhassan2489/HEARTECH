import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/child_card.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

/// HCW Patients list — sorted by risk level descending (High first).
class HcwPatientsScreen extends ConsumerStatefulWidget {
  const HcwPatientsScreen({super.key});

  @override
  ConsumerState<HcwPatientsScreen> createState() => _HcwPatientsScreenState();
}

class _HcwPatientsScreenState extends ConsumerState<HcwPatientsScreen> {
  String _searchQuery = '';
  String _filterRisk = 'all'; // all, high, medium, low, recent
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Risk priority for sorting: high=0, medium=1, low=2
  int _riskPriority(String riskLevel) {
    switch (riskLevel) {
      case 'high': return 0;
      case 'medium': return 1;
      case 'low': return 2;
      default: return 3;
    }
  }

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
        title: childrenAsync.when(
          loading: () => Text('My Patients', style: HearTechTextStyles.sectionHeader()),
          error: (_, _) => Text('My Patients', style: HearTechTextStyles.sectionHeader()),
          data: (children) => Column(
            children: [
              Text('My Patients', style: HearTechTextStyles.sectionHeader()),
              Text('${children.length} patients', style: HearTechTextStyles.caption()),
            ],
          ),
        ),
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
                  controller: _searchCtrl,
                  label: 'Search patients...',
                  prefixIcon: Icons.search,
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['all', 'high', 'medium', 'low', 'recent'].map((chip) {
                      final selected = _filterRisk == chip;
                      final label = chip == 'all' ? 'All'
                          : chip == 'recent' ? 'Recent'
                          : '${chip[0].toUpperCase()}${chip.substring(1)} Risk';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          selectedColor: HearTechColors.deepTeal,
                          backgroundColor: HearTechColors.paleTeal,
                          labelStyle: TextStyle(
                            color: selected ? HearTechColors.white : HearTechColors.deepTeal,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _filterRisk = chip),
                        ),
                      );
                    }).toList(),
                  ),
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
                  // Risk filter
                  if (_filterRisk == 'high' && c.riskLevel != 'high') return false;
                  if (_filterRisk == 'medium' && c.riskLevel != 'medium') return false;
                  if (_filterRisk == 'low' && c.riskLevel != 'low') return false;
                  // Recent filter: screened in last 7 days
                  if (_filterRisk == 'recent') {
                    final isRecent = c.lastScreeningDate != null &&
                        c.lastScreeningDate!.isAfter(DateTime.now().subtract(const Duration(days: 7)));
                    if (!isRecent) return false;
                  }
                  // Search filter
                  if (_searchQuery.isNotEmpty && !c.name.toLowerCase().contains(_searchQuery)) return false;
                  return true;
                }).toList();

                // Default sort: risk level descending (High first)
                filtered.sort((a, b) {
                  final riskCmp = _riskPriority(a.riskLevel).compareTo(_riskPriority(b.riskLevel));
                  if (riskCmp != 0) return riskCmp;
                  return b.lastUpdatedAt.compareTo(a.lastUpdatedAt);
                });

                if (filtered.isEmpty) {
                  final hasPatients = children.isNotEmpty;
                  final hasActiveFilters = _filterRisk != 'all' || _searchQuery.isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care, size: 56, color: HearTechColors.deepTeal.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            hasPatients && hasActiveFilters
                                ? 'No matching patients'
                                : 'No patients yet',
                            style: HearTechTextStyles.subtitle(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasPatients && hasActiveFilters
                                ? 'Try clearing your search or filters.'
                                : 'Start a screening to add your first patient.',
                            style: HearTechTextStyles.caption(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          if (hasPatients && hasActiveFilters)
                            SizedBox(
                              width: 200,
                              child: HearTechButton(
                                label: 'Clear Filters',
                                onPressed: () => setState(() {
                                  _filterRisk = 'all';
                                  _searchQuery = '';
                                  _searchCtrl.clear();
                                }),
                                isSecondary: true,
                              ),
                            )
                          else
                            SizedBox(
                              width: 200,
                              child: HearTechButton(
                                label: 'Start Screening',
                                icon: Icons.add,
                                onPressed: () => context.go(Routes.hcwNewScreening),
                              ),
                            ),
                        ],
                      ),
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
