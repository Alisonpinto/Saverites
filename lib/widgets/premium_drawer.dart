import 'package:flutter/material.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/user_store.dart';
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
      width: MediaQuery.of(context).size.width * 0.78, // ~75-80% of screen
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF121212), // Dark modern background (#121212)
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
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
                  padding: const EdgeInsets.only(left: 12, top: 12),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFA0A0A5), size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ── Profile Header ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1E1F22),
                        const Color(0xFF1E1F22),
                        const Color(0xFF7B61FF).withValues(alpha: 0.15),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Large avatar with a beautiful gradient background and shadow
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4A4A4A),
                              Color(0xFF1A1A1B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: FluttermojiCircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.transparent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              UserStore.instance.currentUser?.name ?? 'Gangster Vagas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${UserStore.instance.currentUser?.userId ?? 'gangster_vagas'}',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFA0A0A5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 4),
              _DrawerItem(
                icon: Icons.bookmark_add_outlined, // Better icon for "Save Item"
                activeIcon: Icons.bookmark_add,
                label: TranslationManager.t('saveItem'),
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  onSaveItemTap();
                },
              ),
              const SizedBox(height: 4),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1, thickness: 1),
              ),
              const SizedBox(height: 16),
              
              _BottomDrawerItem(
                icon: Icons.help_outline_rounded,
                label: TranslationManager.t('helpSupport'),
                onTap: () {
                  Navigator.of(context).pop();
                  onHelpTap();
                },
              ),
              _BottomDrawerItem(
                icon: Icons.settings_outlined,
                label: TranslationManager.t('title'), // Translation for 'Settings'
                onTap: () {
                  Navigator.of(context).pop();
                  onSettingsTap();
                },
              ),
              const SizedBox(height: 4),
              _BottomDrawerItem(
                icon: Icons.logout_outlined,
                label: TranslationManager.t('logout'),
                textColor: const Color(0xFFEB4335), // Simple red text
                iconColor: const Color(0xFFEB4335), // Simple red icon
                onTap: () {
                  Navigator.of(context).pop();
                  onLogoutTap();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// Menu Items: 16px Medium, Icon 22px
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconToShow = selected ? (activeIcon ?? icon) : icon;
    final color = selected ? Colors.white : const Color(0xFFA0A0A5);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Thin left accent indicator
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                splashColor: Colors.white.withValues(alpha: 0.05),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                hoverColor: Colors.white.withValues(alpha: 0.05),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(iconToShow, size: 22, color: color),
                      const SizedBox(width: 16),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500, // Medium font weight
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Bottom Items: 15px Medium, Icon 22px
class _BottomDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _BottomDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final finalIconColor = iconColor ?? const Color(0xFFA0A0A5);
    final finalTextColor = textColor ?? const Color(0xFFA0A0A5);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.05),
        hoverColor: Colors.white.withValues(alpha: 0.05),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: finalIconColor),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15, // 15px Medium
                  fontWeight: FontWeight.w500,
                  color: finalTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
