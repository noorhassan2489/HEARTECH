import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/firestore_service.dart';

/// Screen for teachers to submit classroom hearing observations per Section 8 & 10.
class TeacherObservationScreen extends StatefulWidget {
  final String childId;
  final String childName;
  const TeacherObservationScreen({super.key, required this.childId, required this.childName});

  @override
  State<TeacherObservationScreen> createState() => _TeacherObservationScreenState();
}

class _TeacherObservationScreenState extends State<TeacherObservationScreen> {
  final _firestoreService = FirestoreService();
  bool _isSubmitting = false;

  // Observation checklist items per Master Prompt Section 10
  final List<Map<String, dynamic>> _checks = [
    {'id': 'responds_name', 'label': 'Responds when name is called', 'value': false},
    {'id': 'follows_directions', 'label': 'Follows simple verbal directions', 'value': false},
    {'id': 'participates_circle', 'label': 'Participates during circle/story time', 'value': false},
    {'id': 'speech_clarity', 'label': 'Speech is understandable to peers', 'value': false},
    {'id': 'startled', 'label': 'Appears startled by sudden sounds', 'value': false},
    {'id': 'turns_to_sound', 'label': 'Turns head toward sound sources', 'value': false},
    {'id': 'watches_faces', 'label': 'Watches faces closely during conversation', 'value': false},
    {'id': 'asks_repeat', 'label': 'Frequently asks for repetition ("Huh?", "What?")', 'value': false},
  ];

  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final observationData = {
        'childId': widget.childId,
        'teacherUid': uid,
        'date': DateTime.now().toIso8601String(),
        'checks': {for (var c in _checks) c['id']: c['value']},
        'notes': _notesController.text.trim(),
        'positiveCount': _checks.where((c) => c['value'] == true).length,
        'totalChecks': _checks.length,
      };

      await _firestoreService.addTeacherObservation(widget.childId, observationData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observation submitted successfully!'),
            backgroundColor: AppTheme.safeGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Classroom Observation', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Child info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.child_care, color: Color(0xFF8E44AD), size: 32),
                  const SizedBox(width: 12),
                  Text(widget.childName, style: AppTheme.heading2.copyWith(color: const Color(0xFF8E44AD))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Hearing Behavior Checklist', style: AppTheme.heading1),
            const SizedBox(height: 8),
            Text(
              'Check all behaviors you observe in the classroom setting. Be as accurate as possible.',
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            // Checklist
            ..._checks.asMap().entries.map((entry) {
              final idx = entry.key;
              final check = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: check['value'] ? AppTheme.safeGreen : AppTheme.dividerColor,
                  ),
                ),
                child: CheckboxListTile(
                  title: Text(check['label'], style: AppTheme.bodyText),
                  value: check['value'],
                  activeColor: AppTheme.safeGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onChanged: (val) {
                    setState(() {
                      _checks[idx]['value'] = val ?? false;
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 16),

            // Additional notes
            Text('Additional Notes (optional)', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Any additional observations about the child\'s hearing behavior...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('SUBMIT OBSERVATION'),
            ),
          ],
        ),
      ),
    );
  }
}
