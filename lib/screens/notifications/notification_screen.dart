import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/notification_tile.dart';
import '../../utils/translation_manager.dart';

import '../../utils/notification_manager.dart';
import '../profile/profile_screen.dart';

class NotificationScreen extends StatefulWidget {
  final bool showBottomNav;
  final bool showBackButton;

  const NotificationScreen({
    super.key,
    this.showBottomNav = true,
    this.showBackButton = true,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.instance.markAllAsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, _, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Color(0xFF272729),
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: Column(
              children: [
                // ── Header ────────────────────────────────────────────────────
                _NotificationHeader(
                  statusBarHeight: statusBarHeight,
                  showBackButton: widget.showBackButton,
                ),

                // ── Notification list ─────────────────────────────────────────
                Expanded(
                  child: ValueListenableBuilder<List<NotificationModel>>(
                    valueListenable: NotificationManager.instance.notificationsNotifier,
                    builder: (context, notificationsList, _) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: notificationsList.length,
                        itemBuilder: (context, index) {
                          return NotificationTile(
                            notification: notificationsList[index],
                            // Even-index rows get the alternate (slightly lighter) bg.
                            isAlternate: index.isEven,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    username: notificationsList[index].username,
                                    avatarAssetPath: notificationsList[index].avatarAssetPath,
                                    avatarInitial: notificationsList[index].avatarInitial,
                                    avatarColor: notificationsList[index].avatarColor,
                                    showBottomNav: false,
                                    showBackButton: true,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Bottom navigation — bell tab active ───────────────────────────
            bottomNavigationBar: widget.showBottomNav
                ? AppBottomNavigation(
                    currentIndex: 2,
                    onTabChanged: (index) {
                      if (index == 3) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                      } else if (index == 0 || index == 1) {
                        Navigator.pop(context, index);
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _NotificationHeader extends StatelessWidget {
  final double statusBarHeight;
  final bool showBackButton;

  const _NotificationHeader({
    required this.statusBarHeight,
    required this.showBackButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10,
        bottom: 0,
        left: 8,
        right: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back arrow
          if (showBackButton) ...[
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
          if (!showBackButton) const SizedBox(width: 12),
          // Title
          Text(
            TranslationManager.t('notification'),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
