import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Notification list screen — shared by all roles.
class NotificationsScreen extends ConsumerWidget {
  final String role;
  const NotificationsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: LoadingIndicator());

        final backRoute = role == 'hcw' ? Routes.hcwDashboard
            : role == 'parent' ? Routes.parentDashboard
            : Routes.teacherDashboard;

        return Scaffold(
          backgroundColor: HearTechColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent, elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
              onPressed: () => context.go(backRoute),
            ),
            title: Text('Notifications', style: HearTechTextStyles.sectionHeader()),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: () => ref.read(firestoreServiceProvider).markAllNotificationsRead(user.uid),
                child: Text('Mark all read', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
              ),
            ],
          ),
          body: StreamBuilder(
            stream: ref.read(firestoreServiceProvider).streamNotifications(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LoadingIndicator();
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No notifications', style: HearTechTextStyles.subtitle()),
                      const SizedBox(height: 4),
                      Text("You're all caught up!", style: HearTechTextStyles.caption()),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: notifications.length,
                separatorBuilder: (_, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  final notifColor = _resolveColor(notif.colorKey);
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: notif.read ? HearTechColors.white : HearTechColors.paleTeal,
                      borderRadius: HearTechDecorations.cardBorderRadius,
                      boxShadow: HearTechDecorations.cardShadow,
                      border: notif.read ? null : Border.all(color: HearTechColors.deepTeal.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: notifColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_getNotifIcon(notif.type), color: notifColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif.title, style: HearTechTextStyles.subtitle()),
                              const SizedBox(height: 4),
                              Text(notif.body, style: HearTechTextStyles.caption(),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text(DateFormat('MMM d, h:mm a').format(notif.createdAt),
                                  style: HearTechTextStyles.caption(color: HearTechColors.textSecondary.withValues(alpha: 0.6))),
                            ],
                          ),
                        ),
                        if (!notif.read)
                          Container(width: 8, height: 8,
                              decoration: const BoxDecoration(color: HearTechColors.deepTeal, shape: BoxShape.circle)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Color _resolveColor(String colorKey) {
    switch (colorKey) {
      case 'red': return HearTechColors.coralRed;
      case 'orange': return HearTechColors.warmOrange;
      case 'green': return HearTechColors.green;
      case 'purple': return HearTechColors.purple;
      default: return HearTechColors.deepTeal;
    }
  }

  IconData _getNotifIcon(String type) {
    if (type.contains('screening') || type.contains('HCW-01')) return Icons.assignment;
    if (type.contains('referral') || type.contains('HCW-05')) return Icons.description;
    if (type.contains('invite') || type.startsWith('TCH')) return Icons.mail;
    if (type.contains('claim') || type.contains('PAR-01')) return Icons.link;
    if (type.contains('speech')) return Icons.mic;
    if (type.contains('reminder')) return Icons.schedule;
    return Icons.notifications;
  }
}
