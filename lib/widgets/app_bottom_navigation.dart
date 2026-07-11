import 'package:flutter/material.dart';
import '../utils/tutorial_keys.dart';

/// Full-width bottom navigation bar with a centered Add button.
///
/// Designed to sit flush at the device bottom with a premium yellow FAB.
/// Safe-area padding is applied manually so the bar never overlaps the
/// home indicator on notched / gesture-nav devices.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onAddTap;
  final bool isAddMenuOpen;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.onAddTap,
    required this.isAddMenuOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // ── Main Navigation Bar ──────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 60 + bottomPadding,
          decoration: const BoxDecoration(
            color: Color(0xFF272729),
          ),
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Row(
            children: [
              // Home Tab
              Expanded(
                child: _NavIcon(
                  key: TutorialKeys.homeTabKey,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  index: 0,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                ),
              ),
              
              // Spacer for the center FAB
              const SizedBox(width: 80),
              
              // Profile Tab
              Expanded(
                child: _NavIcon(
                  key: TutorialKeys.profileTabKey,
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  index: 3,
                  currentIndex: currentIndex,
                  onTap: onTabChanged,
                ),
              ),
            ],
          ),
        ),

        // ── Centered Floating Add Button ─────────────────────────────────
        Positioned(
          top: -20, // Overflow the bar top
          child: GestureDetector(
            key: TutorialKeys.addButtonKey,
            onTap: onAddTap,
            child: AnimatedScale(
              scale: isAddMenuOpen ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF096),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFAF096).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedRotation(
                  turns: isAddMenuOpen ? 0.125 : 0.0, // 45 degrees rotation to look like an X
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
    super.key,
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
