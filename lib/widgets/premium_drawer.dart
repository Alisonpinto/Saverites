import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'animated_avatar.dart';
import '../utils/translation_manager.dart';

class PremiumDrawer extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onSaveItemTap;
  final VoidCallback onHelpTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onLogoutTap;

  const PremiumDrawer({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.onSaveItemTap,
    required this.onHelpTap,
    required this.onSettingsTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      elevation: 0,
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF232325),
              Color(0xFF161618),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(32),
            bottomRight: Radius.circular(32),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Bar: Close Button ──────────────────────────────────────
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Profile Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFAF096).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    const AnimatedAvatar(size: 60),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'gangster_vagas',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Navigation Items ───────────────────────────────────────────
              _DrawerItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                selected: currentTab == 0,
                onTap: () {
                  Navigator.of(context).pop();
                  onTabSelected(0);
                },
              ),
              _DrawerItem(
                icon: Icons.save_outlined,
                label: TranslationManager.t('saveItem'), // "Save an Item"
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  onSaveItemTap();
                },
              ),
              _DrawerItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                selected: currentTab == 3,
                onTap: () {
                  Navigator.of(context).pop();
                  onTabSelected(3);
                },
              ),

              const Spacer(),

              // ── Sticky Bottom Section ──────────────────────────────────────
              const Divider(color: Colors.white10, height: 1, thickness: 0.5),
              const SizedBox(height: 12),
              _DrawerItem(
                icon: Icons.help_outline_rounded,
                label: TranslationManager.t('helpSupport'),
                onTap: () {
                  Navigator.of(context).pop();
                  onHelpTap();
                },
              ),
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: TranslationManager.t('title'), // "Settings"
                onTap: () {
                  Navigator.of(context).pop();
                  onSettingsTap();
                },
              ),
              _DrawerItem(
                icon: Icons.logout_outlined,
                label: TranslationManager.t('logout'),
                textColor: const Color(0xFFEB4335),
                iconColor: const Color(0xFFEB4335),
                onTap: () {
                  Navigator.of(context).pop();
                  onLogoutTap();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.selected = false,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected;
    final bool showHighlight = active || _isHovered || _isPressed;
    final iconToShow = showHighlight ? (widget.activeIcon ?? widget.icon) : widget.icon;
    final defaultColor = showHighlight ? Colors.white : const Color(0xFF8E8E93);
    final finalIconColor = widget.iconColor ?? defaultColor;
    final finalTextColor = widget.textColor ?? defaultColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() {
          _scale = 0.95;
          _isPressed = true;
        }),
        onTapUp: (_) {
          setState(() {
            _scale = 1.0;
            _isPressed = false;
          });
          widget.onTap();
        },
        onTapCancel: () => setState(() {
          _scale = 1.0;
          _isPressed = false;
        }),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            height: 54, // Large touch target
            decoration: showHighlight
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFAF096).withValues(alpha: active ? 0.25 : 0.12),
                        Colors.transparent,
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border(
                      left: BorderSide(
                        color: const Color(0xFFFAF096).withValues(alpha: active ? 1.0 : 0.5),
                        width: active ? 4 : 3,
                      ),
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFAF096).withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(2, 2),
                            ),
                          ]
                        : null,
                  )
                : null,
            padding: EdgeInsets.only(
              left: showHighlight ? 12.0 : 16.0,
              right: 16.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  iconToShow,
                  size: 24,
                  color: finalIconColor,
                ),
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: showHighlight ? FontWeight.w600 : FontWeight.w500,
                    color: finalTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
