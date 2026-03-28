import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

/// Notification Preferences — toggles for each notification type,
/// connected to Firestore /users/{uid}/notificationPrefs.
/// High-priority alerts are always locked ON.
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() => _NotificationPrefsState();
}

class _NotificationPrefsState extends ConsumerState<NotificationPrefsScreen> {
  Map<String, bool> _prefs = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // High-priority (always on, cannot be disabled)
  static const _lockedKeys = [
    'HCW_01', 'HCW_09', 'HCW_10',
    'PAR_01', 'PAR_02', 'PAR_03',
    'TCH_01',
  ];

  static const Map<String, _PrefGroup> _groups = {
    'HCW Notifications': _PrefGroup(items: [
      _PrefItem('HCW_01', 'Handover Code Expiring', true),
      _PrefItem('HCW_02', 'Profile Claimed by Parent', false),
      _PrefItem('HCW_03', 'Teacher Linked', false),
      _PrefItem('HCW_04', 'Observation Submitted', false),
      _PrefItem('HCW_05', 'Parent Home Screening', false),
      _PrefItem('HCW_06', 'Follow-Up Overdue', false),
      _PrefItem('HCW_07', 'Referral Generated', false),
      _PrefItem('HCW_08', 'Speech Session Completed', false),
      _PrefItem('HCW_09', 'Risk Level Changed', true),
      _PrefItem('HCW_10', 'Account Verification', true),
    ]),
    'Parent Notifications': _PrefGroup(items: [
      _PrefItem('PAR_01', 'Screening Complete', true),
      _PrefItem('PAR_02', 'Risk Assessment Updated', true),
      _PrefItem('PAR_03', 'Referral Generated', true),
      _PrefItem('PAR_04', 'Teacher Connected', false),
      _PrefItem('PAR_05', 'Invite Declined', false),
      _PrefItem('PAR_06', 'Invite Expiring', false),
      _PrefItem('PAR_07', 'Observation Submitted', false),
      _PrefItem('PAR_08', 'Speech Session Result', false),
      _PrefItem('PAR_09', 'Home Screening Reminder', false),
      _PrefItem('PAR_10', 'New Note from HCW', false),
    ]),
    'Teacher Notifications': _PrefGroup(items: [
      _PrefItem('TCH_01', 'New Student Invite', true),
      _PrefItem('TCH_02', 'Invite Expiring', false),
      _PrefItem('TCH_03', 'Student Risk Change', false),
      _PrefItem('TCH_04', 'Screening Completed', false),
      _PrefItem('TCH_05', 'Speech Session', false),
      _PrefItem('TCH_06', 'Note from HCW', false),
      _PrefItem('TCH_07', 'Observation Reminder', false),
      _PrefItem('TCH_08', 'Access Removed', false),
    ]),
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final uid = ref.read(firebaseAuthServiceProvider).uid;
      if (uid == null) return;
      final user = await ref.read(firestoreServiceProvider).getUser(uid);
      if (user != null) {
        _prefs = Map<String, bool>.from(user.notificationPrefs);
      }
    } catch (e) {
      // Use defaults — all enabled
    }
    setState(() => _isLoading = false);
  }

  Future<void> _savePrefs() async {
    setState(() => _isSaving = true);
    try {
      final uid = ref.read(firebaseAuthServiceProvider).uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUser(uid, {
          'notificationPrefs': _prefs,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Preferences saved.'), backgroundColor: HearTechColors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  bool _isLocked(String key) => _lockedKeys.contains(key);
  bool _isEnabled(String key) => _isLocked(key) || (_prefs[key] ?? true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notification Preferences', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: _groups.entries.map((group) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.key, style: HearTechTextStyles.sectionHeader()),
                          const SizedBox(height: 8),
                          Container(
                            decoration: HearTechDecorations.cardDecoration,
                            child: Column(
                              children: group.value.items.map((item) {
                                final locked = _isLocked(item.key);
                                final enabled = _isEnabled(item.key);
                                return SwitchListTile(
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(item.label, style: HearTechTextStyles.body())),
                                      if (locked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: HearTechColors.coralRed.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.lock, size: 12, color: HearTechColors.coralRed),
                                            const SizedBox(width: 4),
                                            Text('Always On', style: HearTechTextStyles.caption(color: HearTechColors.coralRed)
                                                .copyWith(fontWeight: FontWeight.w700, fontSize: 10)),
                                          ]),
                                        ),
                                    ],
                                  ),
                                  value: enabled,
                                  onChanged: locked
                                      ? null
                                      : (v) => setState(() => _prefs[item.key] = v),
                                  activeTrackColor: HearTechColors.deepTeal.withValues(alpha: 0.3),
                                  dense: true,
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: HearTechButton(
                    label: _isSaving ? 'Saving...' : 'Save Preferences',
                    onPressed: _isSaving ? null : _savePrefs,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PrefGroup {
  final List<_PrefItem> items;
  const _PrefGroup({required this.items});
}

class _PrefItem {
  final String key;
  final String label;
  final bool highPriority;
  const _PrefItem(this.key, this.label, this.highPriority);
}
