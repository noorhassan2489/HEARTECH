import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODEL — one preference item
// ═══════════════════════════════════════════════════════════════════════════════

class _PrefItem {
  final String key;
  final String title;
  final String description;
  final bool alwaysOn; // if true → non-toggleable, show "Always On" chip

  const _PrefItem({
    required this.key,
    required this.title,
    required this.description,
    this.alwaysOn = false,
  });
}

class _PrefSection {
  final String header;
  final List<_PrefItem> items;

  const _PrefSection({required this.header, required this.items});
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROLE-SPECIFIC PREFERENCE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════

const _hcwSections = [
  _PrefSection(header: 'REMINDERS', items: [
    _PrefItem(
      key: 'HCW_06',
      title: 'Follow-Up Screening Due',
      description: 'Remind you when a patient needs a follow-up screening',
    ),
    _PrefItem(
      key: 'HCW_01',
      title: 'Handover Code Expiry',
      description: 'Alert you 2 hours before a handover code expires',
    ),
  ]),
  _PrefSection(header: 'ACTIVITY UPDATES', items: [
    _PrefItem(
      key: 'HCW_02',
      title: 'Profile Claimed by Parent',
      description: 'Notify you when a parent links a child profile',
    ),
    _PrefItem(
      key: 'HCW_03',
      title: 'Teacher Linked to Patient',
      description: "Notify you when a teacher joins a child's profile",
    ),
    _PrefItem(
      key: 'HCW_04',
      title: 'New Teacher Observation',
      description:
          'Notify you when a teacher submits a classroom observation',
    ),
    _PrefItem(
      key: 'HCW_07',
      title: 'Parent Home Screening Submitted',
      description: 'Notify you when a parent completes a home screening',
    ),
    _PrefItem(
      key: 'HCW_08',
      title: 'Speech Session Completed',
      description: 'Notify you when a speech game session is submitted',
    ),
    _PrefItem(
      key: 'HCW_09',
      title: 'HCW Access Removed',
      description: 'Notify you when a parent removes your access',
    ),
    _PrefItem(
      key: 'HCW_10',
      title: 'License Verified',
      description: 'Notify you when your license is approved',
    ),
    _PrefItem(
      key: 'HCW_11',
      title: 'New Patient Invite',
      description: 'Notify you when a parent invites you to join a child profile',
    ),
  ]),
  _PrefSection(header: 'CRITICAL ALERTS — ALWAYS ON', items: [
    _PrefItem(
      key: 'HCW_05',
      title: 'Risk Level Elevated',
      description:
          "Sent when a child's risk level increases. Cannot be disabled.",
      alwaysOn: true,
    ),
  ]),
];

const _parentSections = [
  _PrefSection(header: 'REMINDERS', items: [
    _PrefItem(
      key: 'PAR_09',
      title: 'Home Screening Reminder',
      description: 'Remind you monthly to complete a home screening',
    ),
  ]),
  _PrefSection(header: 'ACTIVITY UPDATES', items: [
    _PrefItem(
      key: 'PAR_02',
      title: 'New Note from Healthcare Provider',
      description:
          "Notify you when your HCW adds a note to your child's record",
    ),
    _PrefItem(
      key: 'PAR_03',
      title: 'Risk Score Updated by HCW',
      description:
          'Notify you when your HCW manually updates the risk score',
    ),
    _PrefItem(
      key: 'PAR_05',
      title: 'Teacher Accepted Invite',
      description: 'Notify you when a teacher accepts your invitation',
    ),
    _PrefItem(
      key: 'PAR_06',
      title: 'Teacher Declined Invite',
      description: 'Notify you when a teacher declines your invitation',
    ),
    _PrefItem(
      key: 'PAR_07',
      title: 'New Classroom Observation',
      description: 'Notify you when a teacher submits an observation',
    ),
    _PrefItem(
      key: 'PAR_08',
      title: 'New Medical Referral',
      description:
          'Notify you when your HCW finalizes a referral letter',
    ),
    _PrefItem(
      key: 'PAR_10',
      title: 'Teacher Unlinked',
      description:
          "Notify you when a teacher is removed from your child's profile",
    ),
  ]),
  _PrefSection(header: 'CRITICAL ALERTS — ALWAYS ON', items: [
    _PrefItem(
      key: 'PAR_04',
      title: 'Health Alert — Risk Level Elevated',
      description:
          "Sent when your child's risk level increases. Cannot be disabled.",
      alwaysOn: true,
    ),
  ]),
];

const _teacherSections = [
  _PrefSection(header: 'REMINDERS', items: [
    _PrefItem(
      key: 'TCH_07',
      title: 'Observation Reminder',
      description:
          'Remind you when 14 days have passed without an observation',
    ),
    _PrefItem(
      key: 'TCH_02',
      title: 'Invite Expiry Warning',
      description: 'Alert you 6 hours before a pending invite expires',
    ),
  ]),
  _PrefSection(header: 'ACTIVITY UPDATES', items: [
    _PrefItem(
      key: 'TCH_01',
      title: 'New Observation Invite',
      description: 'Notify you when a parent sends you an invitation',
    ),
    _PrefItem(
      key: 'TCH_03',
      title: 'Child Risk Level Changed',
      description:
          "Notify you when a linked child's risk level changes",
    ),
    _PrefItem(
      key: 'TCH_04',
      title: 'Note from Healthcare Provider',
      description:
          'Notify you when the HCW shares a note relevant to the classroom',
    ),
    _PrefItem(
      key: 'TCH_06',
      title: 'Parent Removed Your Access',
      description:
          "Notify you when a parent removes you from a child's profile",
    ),
    _PrefItem(
      key: 'TCH_08',
      title: 'Parent Completed Speech Session',
      description:
          'Notify you when a parent submits a speech session result',
    ),
  ]),
  // No "Critical Alerts — Always On" section for teacher (empty → hidden)
];

// ═══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

/// Notification Preferences — role-aware toggles stored in
/// Firestore users/{uid}.notificationPrefs.
/// Each toggle saves immediately on change.
class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsState();
}

class _NotificationPrefsState extends ConsumerState<NotificationPrefsScreen> {
  Map<String, bool> _prefs = {};
  String? _role;
  bool _isLoading = true;

  /// Keys currently being written to Firestore (show spinner).
  final Set<String> _savingKeys = {};

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
        _role = user.role;
      }
    } catch (_) {
      // Use defaults — all enabled
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Toggle a single preference and write immediately to Firestore.
  Future<void> _toggle(String key, bool newValue) async {
    final oldValue = _prefs[key] ?? true;

    // Optimistic UI
    setState(() {
      _prefs[key] = newValue;
      _savingKeys.add(key);
    });

    try {
      final uid = ref.read(firebaseAuthServiceProvider).uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUser(uid, {
          'notificationPrefs.$key': newValue,
        });
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() => _prefs[key] = oldValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }

    if (mounted) setState(() => _savingKeys.remove(key));
  }

  bool _isEnabled(String key) => _prefs[key] ?? true;

  List<_PrefSection> get _sections {
    switch (_role) {
      case 'hcw':
        return _hcwSections;
      case 'parent':
        return _parentSections;
      case 'teacher':
        return _teacherSections;
      default:
        return [];
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notification Preferences',
            style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: _sections
                  .map((section) => _buildSection(section))
                  .toList(),
            ),
    );
  }

  Widget _buildSection(_PrefSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Section header — uppercase, semibold, secondary color
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            section.header,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: HearTechColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        // Cards
        Container(
          decoration: BoxDecoration(
            color: HearTechColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: HearTechDecorations.subtleShadow,
          ),
          child: Column(
            children: _buildItems(section.items),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  List<Widget> _buildItems(List<_PrefItem> items) {
    final widgets = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      widgets.add(_buildRow(items[i]));
      if (i < items.length - 1) {
        widgets.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }
    return widgets;
  }

  Widget _buildRow(_PrefItem item) {
    final enabled = _isEnabled(item.key);
    final isSaving = _savingKeys.contains(item.key);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title + description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: HearTechColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: HearTechColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Right side: toggle or Always On chip or saving spinner
          if (item.alwaysOn)
            _alwaysOnChip()
          else if (isSaving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: HearTechColors.deepTeal,
              ),
            )
          else
            Switch(
              value: enabled,
              onChanged: (v) => _toggle(item.key, v),
              activeThumbColor: HearTechColors.deepTeal,
              activeTrackColor:
                  HearTechColors.deepTeal.withValues(alpha: 0.35),
            ),
        ],
      ),
    );
  }

  Widget _alwaysOnChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Always On',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF757575),
        ),
      ),
    );
  }
}
