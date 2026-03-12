import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_item.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  // Mock data until Firestore stream is wired up
  final List<NotificationItem> _mockItems = [
    NotificationItem(
      id: "1",
      type: "HCW-02",
      title: "Profile Linked",
      body: "Sarah Thompson has linked Emma's profile.",
      read: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      priority: "normal",
      navigationRoute: "/child/123",
    ),
    NotificationItem(
      id: "2",
      type: "PAR-04",
      title: "Risk Level Upgraded",
      body: "Based on recent observations, Noah's risk level is now High.",
      read: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      priority: "high",
      navigationRoute: "/child/456",
    ),
    NotificationItem(
      id: "3",
      type: "HCW-06",
      title: "Follow-up Due",
      body: "Emma is due for a follow-up screening this week.",
      read: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      priority: "normal",
      navigationRoute: "/child/123",
    ),
  ];

  void _markAllRead() {
    setState(() {
      for (var item in _mockItems) {
        // Create new item with read=true (since fields are final)
        final index = _mockItems.indexOf(item);
        if (!item.read) {
          _mockItems[index] = NotificationItem(
            id: item.id,
            type: item.type,
            title: item.title,
            body: item.body,
            read: true,
            createdAt: item.createdAt,
            priority: item.priority,
            navigationRoute: item.navigationRoute,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _mockItems.where((i) => !i.read).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("Notifications", style: AppTheme.heading2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(foregroundColor: AppTheme.primaryTeal),
              child: const Text("Mark All Read"),
            ),
        ],
      ),
      body: _mockItems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              itemCount: _mockItems.length,
              itemBuilder: (context, index) {
                final item = _mockItems[index];
                return _NotificationTile(item: item);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryPale,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 48, color: AppTheme.primaryTeal),
          ),
          const SizedBox(height: 24),
          Text("All caught up!", style: AppTheme.heading2),
          const SizedBox(height: 8),
          Text(
            "No new notifications at this time.",
            style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  // Determines color based on spec
  Color _getBorderColor() {
    final t = item.type;
    if (["HCW-05", "PAR-04", "TCH-03", "HCW-09", "PAR-10", "TCH-06", "PAR-06"].contains(t)) return AppTheme.accentCoral;
    if (["HCW-01", "HCW-06", "PAR-09", "TCH-07", "TCH-02"].contains(t)) return Colors.orange;
    if (["HCW-10", "PAR-01(Verify)", "TCH-05"].contains(t)) return AppTheme.safeGreen;
    if (["HCW-03", "PAR-05", "HCW-04", "PAR-07", "TCH-08", "TCH-01"].contains(t)) return Colors.purple;
    return AppTheme.primaryTeal;
  }

  IconData _getIcon() {
    final t = item.type;
    if (["HCW-01", "TCH-02"].contains(t)) return Icons.schedule;
    if (["HCW-02", "PAR-01"].contains(t)) return Icons.link;
    if (["HCW-03", "PAR-05"].contains(t)) return Icons.school;
    if (["HCW-04", "PAR-07", "TCH-08"].contains(t)) return Icons.assignment_outlined;
    if (["HCW-05", "PAR-04", "TCH-03"].contains(t)) return Icons.warning_amber_rounded;
    if (["HCW-06", "PAR-09", "TCH-07"].contains(t)) return Icons.calendar_today;
    if (["HCW-07"].contains(t)) return Icons.family_restroom;
    if (["HCW-08"].contains(t)) return Icons.mic;
    if (["HCW-09", "PAR-10", "TCH-06", "PAR-06"].contains(t)) return Icons.person_off;
    if (["HCW-10"].contains(t)) return Icons.verified_user;
    if (["PAR-02", "PAR-03", "TCH-04"].contains(t)) return Icons.edit_note;
    if (["PAR-08"].contains(t)) return Icons.file_download;
    if (["TCH-01"].contains(t)) return Icons.mail_outline;
    return Icons.notifications;
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _getBorderColor();
    
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.horizontal,
      background: Container(
        color: AppTheme.safeGreen,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.mark_chat_read, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: AppTheme.accentCoral,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        // TODO: Handle Firestore delete or mark read based on direction
      },
      child: InkWell(
        onTap: () {
          // TODO: Mark read in Firestore
          Navigator.pushNamed(context, item.navigationRoute);
        },
        child: Container(
          decoration: BoxDecoration(
            color: item.read ? Colors.white : AppTheme.primaryPale,
            border: Border(
              left: BorderSide(color: borderColor, width: 4),
              bottom: BorderSide(color: AppTheme.dividerColor),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_getIcon(), color: borderColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: AppTheme.bodyText.copyWith(
                        fontWeight: item.priority == 'high' ? FontWeight.w900 : FontWeight.bold,
                        color: item.priority == 'high' ? AppTheme.accentCoral : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: AppTheme.caption.copyWith(color: AppTheme.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatRelativeTime(item.createdAt),
                style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
