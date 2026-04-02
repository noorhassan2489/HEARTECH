import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:heartech/shared/models/user_model.dart';

/// HCW Profile screen — shows profile info with edit, settings, sign out.
class HcwProfileScreen extends ConsumerWidget {
  const HcwProfileScreen({super.key});

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
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
              onPressed: () => context.go(Routes.hcwDashboard),
            ),
            title: Text('My Profile', style: HearTechTextStyles.sectionHeader()),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar section
                AvatarCircle(name: user.name, photoUrl: user.profilePhotoUrl, radius: 50),
                const SizedBox(height: 16),
                Text(user.name, style: HearTechTextStyles.screenTitle()),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isVerified == true
                        ? HearTechColors.green.withValues(alpha: 0.1)
                        : HearTechColors.warmOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isVerified == true ? '✓ Verified HCW' : '⏳ Pending Verification',
                    style: HearTechTextStyles.caption(
                      color: user.isVerified == true ? HearTechColors.green : HearTechColors.warmOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Info card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: HearTechDecorations.cardDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Profile Information', style: HearTechTextStyles.sectionHeader()),
                      const SizedBox(height: 16),
                      _infoRow(Icons.email_outlined, 'Email', user.email),
                      _infoRow(Icons.badge_outlined, 'Title', user.title ?? '-'),
                      _infoRow(Icons.local_hospital_outlined, 'Specialization', user.specialization ?? '-'),
                      _infoRow(Icons.business_outlined, 'Hospital', user.hospitalName ?? '-'),
                      _infoRow(Icons.location_city, 'City', user.city ?? '-'),
                      _infoRow(Icons.badge, 'License #', user.licenseNumber ?? '-'),
                      if (user.licenseDocUrl != null && user.licenseDocUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.file_present, size: 20, color: HearTechColors.deepTeal),
                              const SizedBox(width: 12),
                              const SizedBox(width: 100, child: Text('License Doc', style: TextStyle(color: HearTechColors.textSecondary, fontSize: 13))),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final Uri url = Uri.parse(user.licenseDocUrl!);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open document.')));
                                      }
                                    }
                                  },
                                  child: const Text('View Document', style: TextStyle(
                                    color: HearTechColors.deepTeal, decoration: TextDecoration.underline, fontWeight: FontWeight.w500)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _infoRow(Icons.wc, 'Gender', user.gender ?? '-'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Settings
                Container(
                  width: double.infinity,
                  decoration: HearTechDecorations.cardDecoration,
                  child: Column(
                    children: [
                      _settingsTile(
                        Icons.edit_outlined, 'Edit Profile',
                        () => _showEditProfile(context, ref, user),
                      ),
                      const Divider(height: 1),
                      _settingsTile(
                        Icons.notifications_outlined, 'Notification Preferences',
                        () => context.go(Routes.notificationPrefs),
                      ),
                      const Divider(height: 1),
                      _settingsTile(
                        Icons.info_outline, 'About HearTech',
                        () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Sign out
                HearTechButton(
                  label: 'Sign Out',
                  onPressed: () async {
                    await ref.read(firebaseAuthServiceProvider).signOut();
                    if (context.mounted) context.go(Routes.splash);
                  },
                  backgroundColor: HearTechColors.coralRed.withValues(alpha: 0.1),
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
          Icon(icon, size: 20, color: HearTechColors.deepTeal),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: HearTechTextStyles.caption())),
          Expanded(child: Text(value, style: HearTechTextStyles.body())),
        ],
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: HearTechColors.deepTeal),
      title: Text(title, style: HearTechTextStyles.body()),
      trailing: const Icon(Icons.chevron_right, color: HearTechColors.textSecondary),
      onTap: onTap,
    );
  }

  void _showEditProfile(BuildContext context, WidgetRef ref, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final titleCtrl = TextEditingController(text: user.title ?? '');
    final specCtrl = TextEditingController(text: user.specialization ?? '');
    final hospitalCtrl = TextEditingController(text: user.hospitalName ?? '');
    final cityCtrl = TextEditingController(text: user.city ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HearTechColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: HearTechColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Edit Profile', style: HearTechTextStyles.screenTitle()),
              const SizedBox(height: 20),
              _editField(nameCtrl, 'Full Name'),
              _editField(titleCtrl, 'Title (e.g., Dr.)'),
              _editField(specCtrl, 'Specialization'),
              _editField(hospitalCtrl, 'Hospital Name'),
              _editField(cityCtrl, 'City'),
              const SizedBox(height: 16),
              HearTechButton(
                label: 'Save Changes',
                onPressed: () async {
                  try {
                    await ref.read(firestoreServiceProvider).updateUser(user.uid, {
                      'name': nameCtrl.text.trim(),
                      'title': titleCtrl.text.trim(),
                      'specialization': specCtrl.text.trim(),
                      'hospitalName': hospitalCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                    });
                    ref.invalidate(currentUserProfileProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated.'), backgroundColor: HearTechColors.green),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: HearTechColors.paleTeal,
          border: OutlineInputBorder(borderRadius: HearTechDecorations.inputBorderRadius, borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
