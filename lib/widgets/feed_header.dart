import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/translation_manager.dart';
import '../utils/notification_manager.dart';
import '../models/notification_model.dart';

/// Fixed header bar rendered above the scrollable feed.
///
/// Contains a hamburger menu (with notification dot) and a pill search bar.
/// Both are wired with callbacks so parent screens can react without this
/// widget knowing about routing or state management.
class FeedHeader extends StatelessWidget {
  /// Called when the hamburger icon is tapped.
  final VoidCallback? onMenuTap;

  /// Called on every search query change.
  final ValueChanged<String>? onSearchChanged;

  /// Called when the search field is tapped.
  final VoidCallback? onSearchTap;

  /// Called when the notification icon is tapped.
  final VoidCallback? onNotificationTap;

  const FeedHeader({
    super.key,
    this.onMenuTap,
    this.onSearchChanged,
    this.onSearchTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, _, _) {
        return Container(
      // Height = fixed inner height + status bar so content never
      // sits under the system status bar on any device.
      height: 62.0 + statusBarHeight,
      color: const Color(0xFF272729),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Hamburger Menu Icon ─────────────────────────────────────────
          GestureDetector(
            onTap: onMenuTap ?? () {},
            behavior: HitTestBehavior.opaque,
            child: const Icon(Icons.menu, color: Colors.white, size: 26),
          ),

          const SizedBox(width: 14),

          // ── Pill search bar ─────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF8E8E93),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onTap: onSearchTap,
                      onChanged: onSearchChanged,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: TranslationManager.t('findAnything'),
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF8E8E93),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── Notifications Icon with Badge ───────────────────────────────
          GestureDetector(
            onTap: onNotificationTap ?? () {},
            behavior: HitTestBehavior.opaque,
            child: ValueListenableBuilder<List<NotificationModel>>(
              valueListenable: NotificationManager.instance.notificationsNotifier,
              builder: (context, notificationsList, _) {
                final bool hasUnread = notificationsList.any((n) => !n.isRead);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 26),
                    if (hasUnread)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF1744),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
