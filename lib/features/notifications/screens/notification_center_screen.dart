import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/di/providers.dart';
import '../../../shared/models/notification_model.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final notifsAsync = ref.watch(notificationsStreamProvider(uid));
    final notifRepo = ref.read(notificationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Notifications', style: AppTheme.heading2),
        centerTitle: true,
        actions: [
          notifsAsync.when(
            data: (list) {
              final hasUnread = list.any((n) => !n.read);
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => notifRepo.markAllRead(uid),
                child: Text('Mark All Read', style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('All caught up!', style: AppTheme.heading2.copyWith(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text('No notifications yet.', style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
              ]),
            );
          }

          // Group by date
          final grouped = _groupByDate(notifications);

          return RefreshIndicator(
            color: AppTheme.primaryTeal,
            onRefresh: () async {
              // Riverpod will auto-refresh the stream
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: grouped.length,
              itemBuilder: (ctx, groupIndex) {
                final group = grouped[groupIndex];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sticky Date Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text(
                        group.label,
                        style: AppTheme.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    ...group.notifications.map((notif) => _NotifItem(
                      notif: notif,
                      onSwipeRight: () => notifRepo.markRead(uid, notif.notifId),
                      onSwipeLeft: () => notifRepo.deleteNotification(uid, notif.notifId),
                      onTap: () {
                        notifRepo.markRead(uid, notif.notifId);
                        if (notif.navigationRoute.isNotEmpty && notif.navigationRoute != '/') {
                          Navigator.pushNamed(context, notif.navigationRoute);
                        }
                      },
                    )),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  List<_NotifGroup> _groupByDate(List<NotificationModel> notifs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayList = <NotificationModel>[];
    final yesterdayList = <NotificationModel>[];
    final earlierList = <NotificationModel>[];

    for (final n in notifs) {
      final nDate = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (nDate == today) {
        todayList.add(n);
      } else if (nDate == yesterday) {
        yesterdayList.add(n);
      } else {
        earlierList.add(n);
      }
    }

    final groups = <_NotifGroup>[];
    if (todayList.isNotEmpty) groups.add(_NotifGroup('TODAY', todayList));
    if (yesterdayList.isNotEmpty) groups.add(_NotifGroup('YESTERDAY', yesterdayList));
    if (earlierList.isNotEmpty) groups.add(_NotifGroup('EARLIER', earlierList));
    return groups;
  }
}

class _NotifGroup {
  final String label;
  final List<NotificationModel> notifications;
  _NotifGroup(this.label, this.notifications);
}

// ═══════════════════════════════════════════════════════════════
//  NOTIFICATION ITEM WIDGET
// ═══════════════════════════════════════════════════════════════

class _NotifItem extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  final VoidCallback onTap;

  const _NotifItem({
    required this.notif,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColorForType(notif.type);
    final icon = _iconForType(notif.type);

    return Dismissible(
      key: Key(notif.notifId),
      background: Container(
        color: AppTheme.primaryPale,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.mark_email_read, color: AppTheme.primaryTeal),
      ),
      secondaryBackground: Container(
        color: AppTheme.accentCoral.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: AppTheme.accentCoral),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onSwipeRight();
          return false; // don't remove from list, just mark read
        } else {
          onSwipeLeft();
          return true; // remove from list
        }
      },
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: notif.read ? Colors.white : AppTheme.primaryPale,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Color Border
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: borderColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: borderColor, size: 20),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif.title,
                          style: AppTheme.bodyText.copyWith(
                            fontWeight: notif.read ? FontWeight.w400 : FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notif.body,
                          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _relativeTime(notif.createdAt),
                          style: AppTheme.caption.copyWith(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Unread dot
                if (!notif.read)
                  Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryTeal,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  /// Mapping from Section 11 of Master Build Prompt
  Color _borderColorForType(String type) {
    // Red border (bold): HCW-05, HCW-09, PAR-04, PAR-06, TCH-03, TCH-06
    const redTypes = {'HCW-05', 'HCW-09', 'PAR-04', 'PAR-06', 'TCH-03', 'TCH-06'};
    // Orange border: HCW-01, HCW-06, PAR-09, PAR-10, TCH-02, TCH-07
    const orangeTypes = {'HCW-01', 'HCW-06', 'PAR-09', 'PAR-10', 'TCH-02', 'TCH-07'};
    // Green border: HCW-10, PAR-05, TCH-05
    const greenTypes = {'HCW-10', 'PAR-05', 'TCH-05'};
    // Purple border: HCW-03, HCW-04, PAR-07, TCH-01
    const purpleTypes = {'HCW-03', 'HCW-04', 'PAR-07', 'TCH-01'};
    // Teal border: everything else

    if (redTypes.contains(type)) return AppTheme.accentCoral;
    if (orangeTypes.contains(type)) return AppTheme.accentYellow;
    if (greenTypes.contains(type)) return AppTheme.accentGreen;
    if (purpleTypes.contains(type)) return const Color(0xFF8E44AD);
    return AppTheme.primaryTeal;
  }

  IconData _iconForType(String type) {
    if (type.contains('01') || type.contains('02')) return Icons.link;
    if (type.contains('03') || type.contains('04')) return Icons.school;
    if (type.contains('05')) return Icons.warning_amber_rounded;
    if (type.contains('06')) return Icons.schedule;
    if (type.contains('07')) return Icons.assignment;
    if (type.contains('08')) return Icons.record_voice_over;
    if (type.contains('09')) return Icons.remove_circle_outline;
    if (type.contains('10')) return Icons.verified;
    return Icons.notifications_outlined;
  }
}
