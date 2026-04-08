import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/constants/firestore_paths.dart';

/// Bell icon with live Firestore unread-count badge and pulse animation.
/// Tapping navigates to the /notifications route (or calls onTap if provided).
class BellIconWithBadge extends StatefulWidget {
  final String uid;

  /// Optional tap callback. If null, auto-navigates to role-specific notifications.
  final VoidCallback? onTap;

  const BellIconWithBadge({
    super.key,
    required this.uid,
    this.onTap,
  });

  @override
  State<BellIconWithBadge> createState() => _BellIconWithBadgeState();
}

class _BellIconWithBadgeState extends State<BellIconWithBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onCountChanged(int newCount) {
    if (newCount > _previousCount && newCount > 0) {
      _pulseController.forward(from: 0);
    }
    _previousCount = newCount;
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    // Auto-navigate based on current route
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/hcw')) {
      context.push('/hcw/notifications');
    } else if (location.startsWith('/parent')) {
      context.push('/parent/notifications');
    } else if (location.startsWith('/teacher')) {
      context.push('/teacher/notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestorePaths.notifications(widget.uid))
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        // Trigger pulse animation when a new notification arrives
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onCountChanged(count);
        });

        return GestureDetector(
          onTap: _handleTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 28,
                  color: HearTechColors.deepTeal,
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: HearTechColors.coralRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 99 ? '99+' : count.toString(),
                          style: HearTechTextStyles.caption(
                            color: HearTechColors.white,
                          ).copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
