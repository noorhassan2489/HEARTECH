import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class NotificationBell extends StatelessWidget {
  final int unreadCount;
  
  const NotificationBell({super.key, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: AppTheme.textPrimary, size: 28),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ).animate(key: ValueKey(unreadCount))
               .scale(duration: 300.ms, curve: Curves.easeOutBack, begin: const Offset(1, 1), end: const Offset(1.3, 1.3))
               .then()
               .scale(duration: 300.ms, curve: Curves.easeInBack, begin: const Offset(1.3, 1.3), end: const Offset(1, 1)),
            ),
        ],
      ),
      onPressed: () {
        Navigator.pushNamed(context, AppRouter.notifications);
      },
    );
  }
}
