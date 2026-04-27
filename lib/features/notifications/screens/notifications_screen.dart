import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/constants/firestore_paths.dart';
import 'package:heartech/shared/models/notification_model.dart';
import 'package:heartech/shared/widgets/loading_indicator.dart';
import 'package:intl/intl.dart';

/// Notification list screen — shared by all roles.
///
/// Architecture: a Firestore stream feeds a LOCAL list that owns the UI.
/// Dismissible never fights with StreamBuilder because the ListView is built
/// from [_notifications], not from the stream snapshot directly.
class NotificationsScreen extends ConsumerStatefulWidget {
  final String role;
  const NotificationsScreen({super.key, required this.role});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// The single source of truth for the UI list.
  List<NotificationModel> _notifications = [];

  /// IDs that the user has dismissed (swiped away). We keep this set so that
  /// if a stream snapshot arrives before the Firestore delete round-trips we
  /// don't accidentally re-add the item.
  final Set<String> _dismissedIds = {};

  /// IDs optimistically marked as read (before Firestore confirms).
  final Set<String> _optimisticReadIds = {};

  /// Whether the very first snapshot has arrived.
  bool _initialLoaded = false;

  /// Firestore stream subscription.
  StreamSubscription<List<NotificationModel>>? _sub;

  /// Current user UID (set once user profile loads).
  String? _uid;

  String get _backRoute {
    switch (widget.role) {
      case 'hcw':
        return Routes.hcwDashboard;
      case 'parent':
        return Routes.parentDashboard;
      default:
        return Routes.teacherDashboard;
    }
  }

  // ─── Stream management ─────────────────────────────────────────────────────

  void _startListening(String uid) {
    _uid = uid;
    _sub?.cancel();
    _sub = ref
        .read(firestoreServiceProvider)
        .streamNotifications(uid)
        .listen(_onStreamData);
  }

  /// Called each time Firestore pushes a new snapshot.
  void _onStreamData(List<NotificationModel> incoming) {
    if (!mounted) return;
    setState(() {
      _initialLoaded = true;

      // Build new list: keep everything from incoming EXCEPT dismissed items.
      _notifications = incoming
          .where((n) => !_dismissedIds.contains(n.notifId))
          .toList();

      // Clean up optimistic-read IDs that Firestore has confirmed.
      _optimisticReadIds.removeWhere(
          (id) => incoming.any((n) => n.notifId == id && n.read));

      // Clean up dismissed IDs that Firestore has already deleted (no longer
      // in incoming), so the set doesn't grow forever.
      final incomingIds = incoming.map((n) => n.notifId).toSet();
      _dismissedIds.removeWhere((id) => !incomingIds.contains(id));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  bool _isRead(NotificationModel n) =>
      n.read || _optimisticReadIds.contains(n.notifId);

  Color _resolveColor(String colorKey) {
    switch (colorKey) {
      case 'red':
        return HearTechColors.coralRed;
      case 'orange':
        return HearTechColors.warmOrange;
      case 'green':
        return HearTechColors.green;
      case 'purple':
        return HearTechColors.purple;
      default:
        return HearTechColors.deepTeal;
    }
  }

  IconData _getNotifIcon(String type) {
    if (type.contains('screening') || type.contains('HCW-01')) {
      return Icons.assignment;
    }
    if (type.contains('referral') || type.contains('HCW-05')) {
      return Icons.description;
    }
    if (type.contains('invite') || type.startsWith('TCH')) return Icons.mail;
    if (type.contains('claim') || type.contains('PAR-01')) return Icons.link;
    if (type.contains('speech')) return Icons.mic;
    if (type.contains('reminder')) return Icons.schedule;
    return Icons.notifications;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  /// Tap: mark as read + navigate.
  Future<void> _onTap(NotificationModel notif) async {
    final uid = _uid;
    if (uid == null) return;

    // 1. Optimistic read
    setState(() => _optimisticReadIds.add(notif.notifId));

    // 2. Firestore
    try {
      await ref
          .read(firestoreServiceProvider)
          .markNotificationRead(uid, notif.notifId);
    } catch (_) {}

    // 3. Navigate
    if (mounted &&
        notif.navigationRoute != null &&
        notif.navigationRoute!.isNotEmpty) {
      context.go(notif.navigationRoute!);
    }
  }

  /// Swipe right: mark as read (no navigation).
  Future<void> _onSwipeRight(NotificationModel notif) async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _optimisticReadIds.add(notif.notifId));
    try {
      await ref
          .read(firestoreServiceProvider)
          .markNotificationRead(uid, notif.notifId);
    } catch (_) {}
  }

  /// Swipe left: dismiss with undo.
  void _onDismissed(NotificationModel notif) {
    final uid = _uid;
    if (uid == null) return;

    // 1. Remove from local list immediately
    final notifData = notif.toJson();
    final removedIndex =
        _notifications.indexWhere((n) => n.notifId == notif.notifId);
    setState(() {
      _dismissedIds.add(notif.notifId);
      _notifications.removeWhere((n) => n.notifId == notif.notifId);
    });

    // 2. Delete from Firestore
    ref
        .read(firestoreServiceProvider)
        .deleteNotification(uid, notif.notifId)
        .catchError((_) {
      // If Firestore delete fails, put the item back
      if (mounted) {
        setState(() {
          _dismissedIds.remove(notif.notifId);
          if (removedIndex >= 0 && removedIndex <= _notifications.length) {
            _notifications.insert(
                removedIndex, NotificationModel.fromJson(notifData));
          } else {
            _notifications.add(NotificationModel.fromJson(notifData));
          }
        });
      }
    });

    // 3. SnackBar with Undo
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification dismissed'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: HearTechColors.white,
          onPressed: () async {
            // Restore in Firestore
            try {
              await FirebaseFirestore.instance
                  .collection(FirestorePaths.notifications(uid))
                  .doc(notif.notifId)
                  .set(notifData);
            } catch (_) {}
            // Put back in local list immediately
            if (mounted) {
              setState(() {
                _dismissedIds.remove(notif.notifId);
                // The stream callback will add it back on next snapshot,
                // but add it now for instant feedback.
                if (!_notifications.any((n) => n.notifId == notif.notifId)) {
                  if (removedIndex >= 0 &&
                      removedIndex <= _notifications.length) {
                    _notifications.insert(
                        removedIndex, NotificationModel.fromJson(notifData));
                  } else {
                    _notifications.add(NotificationModel.fromJson(notifData));
                  }
                }
              });
            }
          },
        ),
        backgroundColor: HearTechColors.deepTeal,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Mark all as read.
  void _markAllRead() {
    final uid = _uid;
    if (uid == null) return;

    // 1. Optimistic: mark every item read locally
    setState(() {
      for (final n in _notifications) {
        _optimisticReadIds.add(n.notifId);
      }
    });

    // 2. Firestore batch
    ref.read(firestoreServiceProvider).markAllNotificationsRead(uid);

    // 3. SnackBar
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: HearTechColors.green,
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProfileProvider);

    return userAsync.when(
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (user) {
        if (user == null) return const Scaffold(body: LoadingIndicator());

        // Start listening if we haven't, or if uid changed.
        if (_uid != user.uid) {
          _startListening(user.uid);
        }

        return Scaffold(
          backgroundColor: HearTechColors.background,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: HearTechColors.textPrimary),
              onPressed: () => context.go(_backRoute),
            ),
            title: Text('Notifications',
                style: HearTechTextStyles.sectionHeader()),
            centerTitle: true,
            actions: [
              TextButton(
                onPressed: _markAllRead,
                child: Text('Mark all read',
                    style: HearTechTextStyles.caption(
                        color: HearTechColors.deepTeal)),
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    if (!_initialLoaded) {
      return const LoadingIndicator();
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 64,
                color: HearTechColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No notifications', style: HearTechTextStyles.subtitle()),
            const SizedBox(height: 4),
            Text("You're all caught up!",
                style: HearTechTextStyles.caption()),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _notifications.length,
      separatorBuilder: (_, i) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        final isRead = _isRead(notif);
        final notifColor = _resolveColor(notif.colorKey);

        return Dismissible(
          key: ValueKey(notif.notifId),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              // Swipe left → dismiss
              return true;
            } else {
              // Swipe right → mark as read only
              await _onSwipeRight(notif);
              return false;
            }
          },
          onDismissed: (_) => _onDismissed(notif),
          background: Container(
            // Swipe right background (mark read)
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24),
            decoration: BoxDecoration(
              color: HearTechColors.green,
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: const Row(
              children: [
                Icon(Icons.done_all, color: HearTechColors.white),
                SizedBox(width: 8),
                Text('Mark Read',
                    style: TextStyle(
                        color: HearTechColors.white,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          secondaryBackground: Container(
            // Swipe left background (delete)
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: HearTechColors.coralRed,
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Dismiss',
                    style: TextStyle(
                        color: HearTechColors.white,
                        fontWeight: FontWeight.w600)),
                SizedBox(width: 8),
                Icon(Icons.delete_outline, color: HearTechColors.white),
              ],
            ),
          ),
          child: GestureDetector(
            onTap: () => _onTap(notif),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRead ? HearTechColors.white : HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
                boxShadow: HearTechDecorations.cardShadow,
                border: isRead
                    ? null
                    : Border.all(
                        color:
                            HearTechColors.deepTeal.withValues(alpha: 0.2)),
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
                    child: Icon(_getNotifIcon(notif.type),
                        color: notifColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notif.title,
                            style: HearTechTextStyles.subtitle()),
                        const SizedBox(height: 4),
                        Text(notif.body,
                            style: HearTechTextStyles.caption(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMM d, h:mm a')
                              .format(notif.createdAt),
                          style: HearTechTextStyles.caption(
                              color: HearTechColors.textSecondary
                                  .withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: HearTechColors.deepTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
