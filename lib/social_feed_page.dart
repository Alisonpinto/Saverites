import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'utils/post_store.dart';

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark outer bezel mock
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40), // Premium mobile screen rounding
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF121212), // Main feed body dark background
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  // Header Block (Responsive Height, Figma color #272729)
                  _buildHeader(context),
                  // Masonry Feed
                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            // Simulate network fetch
                            await Future.delayed(const Duration(milliseconds: 1500));
                          },
                          builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                            double percentage = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
                            
                            // Make it spin slightly if it's actively refreshing
                            Widget logo = Image.asset(
                              'assets/images/app_logo_memoria.png',
                              width: 36,
                              height: 36,
                              color: Colors.white, // Applying white to ensure it fits the premium dark theme
                            );
                            
                            if (refreshState == RefreshIndicatorMode.refresh) {
                               // simple visual cue during refresh could just be the logo fully opaque
                               percentage = 1.0;
                            }

                            return Center(
                              child: Opacity(
                                opacity: percentage,
                                child: Transform.scale(
                                  scale: 0.8 + (0.2 * percentage), // Small scale up effect
                                  child: logo,
                                ),
                              ),
                            );
                          },
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverToBoxAdapter(
                            child: ValueListenableBuilder<List<UserPost>>(
                              valueListenable: PostStore.instance.postsNotifier,
                              builder: (context, posts, child) {
                                final leftColumn = <Widget>[];
                                final rightColumn = <Widget>[];

                                for (int i = 0; i < posts.length; i++) {
                                  final post = posts[i];
                                  final card = _buildUserPostCard(post);
                                  if (i % 2 == 0) {
                                    leftColumn.add(card);
                                  } else {
                                    rightColumn.add(card);
                                  }
                                }

                                if (posts.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 100),
                                      child: Text(
                                        'No posts yet. Write a post to see it here!',
                                        style: GoogleFonts.inter(
                                          color: Colors.white54,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                final leftColWidgets = <Widget>[];
                                for (var w in leftColumn) {
                                  leftColWidgets.add(w);
                                  leftColWidgets.add(const SizedBox(height: 24));
                                }

                                final rightColWidgets = <Widget>[];
                                for (var w in rightColumn) {
                                  rightColWidgets.add(w);
                                  rightColWidgets.add(const SizedBox(height: 24));
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(children: leftColWidgets),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(children: rightColWidgets),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _buildBottomNavBar(),
            ),
          ),
        ),
      ),
    );
  }

  // --- Header Panel (Figma #272729, Responsive status bar top-padding) ---
  Widget _buildHeader(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // Calculate final responsive height including status bar height (standard 85 on desktop)
    final double finalHeaderHeight = 85.0 + (statusBarHeight > 0 ? statusBarHeight : 0);

    return Container(
      height: finalHeaderHeight,
      color: const Color(0xFF272729),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10, // Safe padding fallback
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hamburger Menu Icon with Red Notification Dot
          GestureDetector(
            onTap: () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 28,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Pill Search Bar with white outline
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: Colors.white,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Find anything',
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
        ],
      ),
    );
  }

  // --- Dynamic User Post Card ---
  Widget _buildUserPostCard(UserPost post) {
    Widget imageWidget;
    // Generate a somewhat varied height based on content length for masonry effect
    double height = 150.0 + ((post.title.length + post.body.length) % 5) * 30.0;
    height = height.clamp(150.0, 300.0);

    if (post.imagePath != null && File(post.imagePath!).existsSync()) {
      imageWidget = Image.file(
        File(post.imagePath!),
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
      );
    } else {
      imageWidget = Container(
        height: height,
        width: double.infinity,
        color: const Color(0xFF2C2C2E),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            post.body.isNotEmpty ? post.body : post.title,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FeedCard(
      title: post.title,
      likes: '0',
      bookmarks: '0',
      shares: '0',
      imageWidget: imageWidget,
    );
  }

  // --- Custom Navigation Bar (Figma #272729) ---
  Widget _buildBottomNavBar() {
    return Container(
      height: 72,
      color: const Color(0xFF272729),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentTab = 0),
            icon: Icon(
              _currentTab == 0 ? Icons.home : Icons.home_outlined,
              color: _currentTab == 0 ? Colors.white : const Color(0xFF8E8E93),
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _currentTab = 1),
            icon: Icon(
              Icons.search,
              color: _currentTab == 1 ? Colors.white : const Color(0xFF8E8E93),
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentTab = 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _currentTab == 2 ? Icons.notifications : Icons.notifications_none_outlined,
                  color: _currentTab == 2 ? Colors.white : const Color(0xFF8E8E93),
                  size: 28,
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Text(
                      '1',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _currentTab = 3),
            icon: Icon(
              _currentTab == 3 ? Icons.bookmark : Icons.bookmark_border,
              color: _currentTab == 3 ? Colors.white : const Color(0xFF8E8E93),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Reusable Card Wrapper ---
class FeedCard extends StatelessWidget {
  final Widget imageWidget;
  final String likes;
  final String bookmarks;
  final String shares;
  final String? title;

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.likes,
    required this.bookmarks,
    required this.shares,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E), // Apple Dark Mode Card Color
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large visual image area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: imageWidget,
          ),
          // Content Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500, // Medium font weight
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Cleaner icon row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconText(Icons.favorite_border, likes),
                    _buildIconText(Icons.bookmark_border, bookmarks),
                    _buildIconText(Icons.ios_share, shares),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFF8E8E93), // Apple standard gray
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF8E8E93),
          ),
        ),
      ],
    );
  }
}
