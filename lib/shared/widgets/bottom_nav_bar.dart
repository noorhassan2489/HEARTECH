import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';

/// Role-aware bottom navigation bar with teal active styling.
class HearTechBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String role; // 'hcw', 'parent', 'teacher'

  const HearTechBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: HearTechColors.white,
        boxShadow: [
          BoxShadow(
            color: HearTechColors.deepTeal.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _getItems().asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isActive = index == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? HearTechColors.paleTeal
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          size: 24,
                          color: isActive
                              ? HearTechColors.deepTeal
                              : HearTechColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: HearTechTextStyles.caption(
                          color: isActive
                              ? HearTechColors.deepTeal
                              : HearTechColors.textSecondary,
                        ).copyWith(
                          fontWeight: isActive ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  List<_NavItem> _getItems() {
    switch (role) {
      case 'hcw':
        return const [
          _NavItem(Icons.home_outlined, Icons.home, 'Home'),
          _NavItem(Icons.people_outline, Icons.people, 'Patients'),
          _NavItem(Icons.notifications_outlined, Icons.notifications, 'Alerts'),
          _NavItem(Icons.person_outline, Icons.person, 'Profile'),
        ];
      case 'parent':
        return const [
          _NavItem(Icons.home_outlined, Icons.home, 'Home'),
          _NavItem(Icons.child_care_outlined, Icons.child_care, 'Children'),
          _NavItem(Icons.mic_outlined, Icons.mic, 'Speech'),
          _NavItem(Icons.notifications_outlined, Icons.notifications, 'Alerts'),
          _NavItem(Icons.person_outline, Icons.person, 'Profile'),
        ];
      case 'teacher':
        return const [
          _NavItem(Icons.home_outlined, Icons.home, 'Home'),
          _NavItem(Icons.school_outlined, Icons.school, 'My Class'),
          _NavItem(Icons.notifications_outlined, Icons.notifications, 'Alerts'),
          _NavItem(Icons.person_outline, Icons.person, 'Profile'),
        ];
      default:
        return const [];
    }
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem(this.icon, this.activeIcon, this.label);
}
