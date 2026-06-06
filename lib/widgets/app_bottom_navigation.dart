import 'package:flutter/material.dart';

/// Full-width bottom navigation bar.
///
/// Designed to sit flush at the device bottom (no gap, no border-radius).
/// Safe-area padding is applied manually so the bar never overlaps the
/// home indicator on notched / gesture-nav devices.
///
/// Tabs: Home · Search · Notifications · Bookmarks.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: const Color(0xFF272729),
      // Add safe-area bottom padding so content sits above the home indicator.
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              index: 0,
              currentIndex: currentIndex,
              onTap: onTabChanged,
            ),
            _NavIcon(
              icon: Icons.search,
              activeIcon: Icons.search,
              index: 1,
              currentIndex: currentIndex,
              onTap: onTabChanged,
            ),
            _NotificationIcon(
              index: 2,
              currentIndex: currentIndex,
              onTap: onTabChanged,
              badge: '1',
            ),
            _NavIcon(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              index: 3,
              currentIndex: currentIndex,
              onTap: onTabChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = index == currentIndex;
    return IconButton(
      onPressed: () => onTap(index),
      icon: Icon(
        active ? activeIcon : icon,
        color: active ? Colors.white : const Color(0xFF8E8E93),
        size: 26,
      ),
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final String? badge;

  const _NotificationIcon({
    required this.index,
    required this.currentIndex,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(
              active
                  ? Icons.notifications
                  : Icons.notifications_none_outlined,
              color: active ? Colors.white : const Color(0xFF8E8E93),
              size: 26,
            ),
            if (badge != null)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF1744),
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
