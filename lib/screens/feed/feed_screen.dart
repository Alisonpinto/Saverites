import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/post_model.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/post_detail/post_detail_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/feed_header.dart';
import '../../widgets/post_card.dart';

/// Social feed screen — skeleton state.
///
/// All dummy images and hardcoded content have been removed.
/// Cards render as empty layout templates ready for real user uploads.
/// Replace [_leftHeights] / [_rightHeights] with a data stream from
/// Firebase when the backend is connected.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _currentTab = 0;

  // Card heights define the masonry rhythm.
  // Stagger them so the two columns feel naturally offset.
  static const List<double> _leftHeights = [260.0, 180.0, 240.0];
  static const List<double> _rightHeights = [180.0, 260.0, 160.0];

  /// Returns a [PostCard] with an empty dark media area — no image, no text.
  /// This is the canonical template every future post will follow.
  Widget _skeletonCard(double height) {
    final post = PostModel(
      id: 'skeleton-$height',
      mediaAssetPath: '',
      likesCount: 0,
      savesCount: 0,
      sharesCount: 0,
      cardHeight: height,
    );

    return PostCard(
      post: post,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: Container(
        height: height,
        width: double.infinity,
        // Neutral empty media surface — dark enough to sit on #121212.
        color: const Color(0xFF2A2A2E),
      ),
    );
  }

  Widget _column(List<double> heights) {
    return Expanded(
      child: Column(
        children: [
          for (int i = 0; i < heights.length; i++) ...[
            _skeletonCard(heights[i]),
            if (i < heights.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Paint the Android system navigation bar (Back/Home/Recent)
      // the same colour as the footer so they feel like one surface.
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF272729),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Column(
          children: [
            // ── Fixed header ────────────────────────────────────────────
            FeedHeader(
              onMenuTap: () {
                // TODO: open side drawer
              },
              onSearchChanged: (query) {
                // TODO: filter cards by query
              },
            ),

            // ── Scrollable masonry grid ─────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _column(_leftHeights),
                    const SizedBox(width: 12),
                    _column(_rightHeights),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Bottom navigation ─────────────────────────────────────────────
        // The AnnotatedRegion above colours the system nav bar to match,
        // removing the visual seam between footer and device chrome.
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab,
          onTabChanged: (index) {
            if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
                ),
              );
            } else if (index == 3) {
              // Person icon → push ProfileScreen.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            } else {
              setState(() => _currentTab = index);
            }
          },
        ),
      ),
    );
  }
}
