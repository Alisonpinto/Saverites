import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/notification_tile.dart';
import '../../utils/translation_manager.dart';

/// Notification centre screen.
///
/// Opened by tapping the bell icon in [AppBottomNavigation].
/// Shows a scrollable list of [NotificationTile] rows with alternating
/// row backgrounds, matching the Figma design.
///
/// Replace [_sampleNotifications] with a `StreamBuilder<List<NotificationModel>>`
/// connected to Firestore when the backend is ready.
class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // ── Sample data ────────────────────────────────────────────────────────────
  //
  // Structured as a typed list. Every field maps to a Firestore field.
  // Colours are deterministic per user — in production derive from user ID hash.

  static const List<NotificationModel> _notifications = [
    NotificationModel(
      id: 'n1',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'A',
      avatarColor: Color(0xFF4A90E2),
      username: 'alex.creates',
      previewText: 'liked your post',
      timestamp: '52m',
      isRead: false,
    ),
    NotificationModel(
      id: 'n2',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'S',
      avatarColor: Color(0xFF7B61FF),
      username: 'sara.m',
      previewText: 'started following you',
      timestamp: '1h',
      isRead: false,
    ),
    NotificationModel(
      id: 'n3',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'J',
      avatarColor: Color(0xFFE24A6A),
      username: 'jordan',
      previewText: 'saved your post',
      timestamp: '3h',
      isRead: true,
    ),
    NotificationModel(
      id: 'n4',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'M',
      avatarColor: Color(0xFF2ECC71),
      username: 'mia.visual',
      previewText: 'commented: "This is stunning 🔥"',
      timestamp: '5h',
      isRead: true,
    ),
    NotificationModel(
      id: 'n5',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'R',
      avatarColor: Color(0xFFE67E22),
      username: 'ravi.dev',
      previewText: 'liked your post',
      timestamp: '8h',
      isRead: true,
    ),
    NotificationModel(
      id: 'n6',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'L',
      avatarColor: Color(0xFF1ABC9C),
      username: 'luna.arts',
      previewText: 'started following you',
      timestamp: '1d',
      isRead: true,
    ),
    NotificationModel(
      id: 'n7',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'K',
      avatarColor: Color(0xFF9B59B6),
      username: 'kai.shoots',
      previewText: 'shared your post',
      timestamp: '1d',
      isRead: true,
    ),
    NotificationModel(
      id: 'n8',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'P',
      avatarColor: Color(0xFFE74C3C),
      username: 'priya.lens',
      previewText: 'liked your post',
      timestamp: '2d',
      isRead: true,
    ),
    NotificationModel(
      id: 'n9',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'T',
      avatarColor: Color(0xFF3498DB),
      username: 'tom.ink',
      previewText: 'commented: "Where was this taken?"',
      timestamp: '3d',
      isRead: true,
    ),
    NotificationModel(
      id: 'n10',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'Z',
      avatarColor: Color(0xFFF39C12),
      username: 'zara.film',
      previewText: 'started following you',
      timestamp: '5d',
      isRead: true,
    ),
  ];

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
            _NotificationHeader(statusBarHeight: statusBarHeight),

            // ── Notification list ─────────────────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  return NotificationTile(
                    notification: _notifications[index],
                    // Even-index rows get the alternate (slightly lighter) bg.
                    isAlternate: index.isEven,
                    onTap: () {
                      // TODO: mark as read + open notification detail
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // ── Bottom navigation — bell tab active ───────────────────────────
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: 2,
          onTabChanged: (index) {
            if (index != 2) {
              // Any other tab → return to feed so it can handle routing.
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _NotificationHeader extends StatelessWidget {
  final double statusBarHeight;

  const _NotificationHeader({required this.statusBarHeight});

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
