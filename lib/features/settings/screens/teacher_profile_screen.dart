import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/editable_profile_avatar.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/models/user_model.dart';

/// Teacher Profile screen.
class TeacherProfileScreen extends ConsumerWidget {
  const TeacherProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: LoadingIndicator());

        return Scaffold(
          backgroundColor: HearTechColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: HearTechColors.textPrimary,
              ),
              onPressed: () => context.go(Routes.teacherDashboard),
            ),
            title: Text(
              'My Profile',
              style: HearTechTextStyles.sectionHeader(),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                EditableProfileAvatar(
                  uid: user.uid,
                  name: user.name,
                  photoUrl: user.profilePhotoUrl,
                  radius: 50,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap photo to change',
                  style: HearTechTextStyles.caption(color: HearTechColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Text(user.name, style: HearTechTextStyles.screenTitle()),
                const SizedBox(height: 4),
                Text(
                  'Teacher Account',
                  style: HearTechTextStyles.caption(
                    color: HearTechColors.purple,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile Information',
                        style: HearTechTextStyles.sectionHeader(),
                      ),
                      const SizedBox(height: 16),
                      _infoRow(Icons.email_outlined, 'Email', user.email),
                      _infoRow(Icons.wc, 'Gender', user.gender ?? '-'),
                      _infoRow(
                        Icons.school_outlined,
                        'School',
                        user.schoolName ?? '-',
                      ),
                      _infoRow(Icons.location_city, 'City', user.city ?? '-'),
                      _infoRow(
                        Icons.timeline,
                        'Experience',
                        user.yearsExperience != null
                            ? '${user.yearsExperience} years'
                            : '-',
                      ),
                      if (user.gradeLevelsTaught != null &&
                          user.gradeLevelsTaught!.isNotEmpty)
                        _infoRow(
                          Icons.grade,
                          'Grades',
                          user.gradeLevelsTaught!.join(', '),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  decoration: HearTechDecorations.cardDecoration,
                  child: Column(
                    children: [
                      _settingsTile(
                        Icons.edit_outlined,
                        'Edit Profile',
                        () => _showEditProfile(context, ref, user),
                      ),
                      const Divider(height: 1),
                      _settingsTile(
                        Icons.notifications_outlined,
                        'Notification Preferences',
                        () => context.push(Routes.notificationPrefs),
                      ),
                      const Divider(height: 1),
                      _settingsTile(
                        Icons.info_outline,
                        'About HearTech',
                        () => context.push(Routes.about),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                HearTechButton(
                  label: 'Sign Out',
                  onPressed: () async {
                    await ref.read(firebaseAuthServiceProvider).signOut();
                    if (context.mounted) context.go(Routes.splash);
                  },
                  backgroundColor: HearTechColors.coralRed.withValues(
                    alpha: 0.1,
                  ),
                  textColor: HearTechColors.coralRed,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: HearTechColors.purple),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label, style: HearTechTextStyles.caption()),
          ),
          Expanded(child: Text(value, style: HearTechTextStyles.body())),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: HearTechColors.purple),
      title: Text(title, style: HearTechTextStyles.body()),
      trailing: const Icon(
        Icons.chevron_right,
        color: HearTechColors.textSecondary,
      ),
      onTap: onTap,
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final schoolCtrl = TextEditingController(text: user.schoolName ?? '');
    final cityCtrl = TextEditingController(text: user.city ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HearTechColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HearTechColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Edit Profile', style: HearTechTextStyles.screenTitle()),
              const SizedBox(height: 20),
              _editField(nameCtrl, 'Full Name'),
              _editField(schoolCtrl, 'School Name'),
              _editField(cityCtrl, 'City'),
              const SizedBox(height: 16),
              HearTechButton(
                label: 'Save Changes',
                onPressed: () async {
                  try {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateUser(user.uid, {
                          'name': nameCtrl.text.trim(),
                          'schoolName': schoolCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                        });
                    ref.invalidate(currentUserProfileProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile updated.'),
                          backgroundColor: HearTechColors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: HearTechColors.paleTeal,
        border: OutlineInputBorder(
          borderRadius: HearTechDecorations.inputBorderRadius,
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
