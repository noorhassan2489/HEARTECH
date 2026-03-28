import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  Map<String, bool> _prefs = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();
    if (data != null && data['notificationPrefs'] != null) {
      setState(() {
        _prefs = Map<String, bool>.from(data['notificationPrefs']);
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _prefs[key] = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'notificationPrefs.$key': value,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Notification Preferences', style: AppTheme.heading2)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCoral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentCoral.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.accentCoral),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Risk alerts (HCW-05, PAR-04) are permanently enabled and cannot be disabled.',
                        style: AppTheme.caption.copyWith(color: AppTheme.accentCoral),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('General Notifications', style: AppTheme.heading2),
                const SizedBox(height: 12),
                _ToggleTile('Screening Reminders', 'screening_reminders', _prefs['screening_reminders'] ?? true),
                _ToggleTile('Teacher Observation Updates', 'teacher_observations', _prefs['teacher_observations'] ?? true),
                _ToggleTile('Handover Code Expiry Warnings', 'handover_expiry', _prefs['handover_expiry'] ?? true),
                _ToggleTile('Speech Module Results', 'speech_results', _prefs['speech_results'] ?? true),
                _ToggleTile('Referral Notifications', 'referral_updates', _prefs['referral_updates'] ?? true),
                _ToggleTile('Invite Updates', 'invite_updates', _prefs['invite_updates'] ?? true),
              ],
            ),
    );
  }

  Widget _ToggleTile(String label, String key, bool value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration,
      child: SwitchListTile(
        title: Text(label, style: AppTheme.bodyText),
        value: value,
        activeTrackColor: AppTheme.primaryTeal,
        onChanged: (val) => _toggle(key, val),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
