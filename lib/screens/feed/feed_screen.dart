import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post_model.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/post_detail/post_detail_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../utils/post_store.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/feed_header.dart';
import '../../widgets/shimmer_container.dart';
import '../../widgets/feed_card.dart';
import '../../widgets/running_video_player.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _currentTab = 0;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnectivity();
    });
    // Listen for new posts to rebuild
    PostStore.instance.postsNotifier.addListener(_onPostsChanged);
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    PostStore.instance.postsNotifier.removeListener(_onPostsChanged);
    super.dispose();
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    } catch (_) {
      if (mounted && _isOnline != false) {
        setState(() => _isOnline = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPosts = PostStore.instance.posts;
    final predefinedPosts = PostStore.predefinedPosts;
    
    // Merge user posts and predefined posts in a single chronological stream
    final List<dynamic> allItems = [...userPosts, ...predefinedPosts];

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
            FeedHeader(
              onMenuTap: () {},
              onSearchChanged: (query) {},
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: PostStore.instance.savedSocialPostIdsNotifier,
                  builder: (context, savedSocialIds, _) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column
                        Expanded(
                          child: Column(
                            children: _buildStaggeredList(allItems, left: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Right Column
                        Expanded(
                          child: Column(
                            children: _buildStaggeredList(allItems, left: false),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab,
          onTabChanged: (index) {
            if (index == 2) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationScreen()));
            } else if (index == 3) {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
            } else {
              setState(() => _currentTab = index);
            }
          },
        ),
      ),
    );
  }

  List<Widget> _buildStaggeredList(List<dynamic> allItems, {required bool left}) {
    final List<Widget> columnWidgets = [];
    
    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      final itemId = item is UserPost ? item.id : (item as PostModel).id;
      final isLeftIndex = itemId.hashCode.isEven;
      if (isLeftIndex != left) continue;

      double cardHeight = 200.0;

      if (item is UserPost) {
        // Stagger heights for user posts dynamically using stable hash index
        final heights = [270.0, 210.0, 250.0, 180.0];
        final hIdx = itemId.hashCode.abs() % heights.length;
        cardHeight = heights[hIdx];
      } else if (item is PostModel) {
        cardHeight = item.cardHeight;
      }

      columnWidgets.add(
        _FeedPostTile(
          key: ValueKey(itemId),
          item: item,
          cardHeight: cardHeight,
          isOnline: _isOnline,
        ),
      );
      columnWidgets.add(const SizedBox(height: 12));
    }
    return columnWidgets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Feed Post Tile — represents a single staggered tile inside feed columns
// ─────────────────────────────────────────────────────────────────────────────
class _FeedPostTile extends StatefulWidget {
  final dynamic item;
  final double cardHeight;
  final bool isOnline;

  const _FeedPostTile({
    super.key,
    required this.item,
    required this.cardHeight,
    required this.isOnline,
  });

  @override
  State<_FeedPostTile> createState() => _FeedPostTileState();
}

class _FeedPostTileState extends State<_FeedPostTile> {
  static final Set<String> _shimmeredIds = {};
  late bool _showShimmer;

  @override
  void initState() {
    super.initState();
    final itemId = widget.item is UserPost ? (widget.item as UserPost).id : (widget.item as PostModel).id;
    if (_shimmeredIds.contains(itemId)) {
      _showShimmer = false;
    } else {
      _showShimmer = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          setState(() {
            _showShimmer = false;
            _shimmeredIds.add(itemId);
          });
        }
      });
    }
  }

  String _format(int count) {
    if (count >= 1000) {
      final double v = count / 1000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final showShimmer = !widget.isOnline || _showShimmer;
    
    void onTap() {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, _, _) {
            if (widget.item is UserPost) {
              return PostDetailScreen(userPost: widget.item as UserPost);
            } else {
              return PostDetailScreen(postModel: widget.item as PostModel);
            }
          },
          transitionsBuilder: (context, animation, _, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }

    if (showShimmer) {
      return ShimmerContainer(
        key: const ValueKey('shimmer'),
        height: widget.cardHeight,
        baseColor: const Color(0xFF2A2A2E),
      );
    }

    final isSaved = widget.item is UserPost
        ? (widget.item as UserPost).savedInProfile
        : PostStore.instance.savedSocialPostIds.contains((widget.item as PostModel).id);

    final likes = widget.item is UserPost ? '1k' : _format((widget.item as PostModel).likesCount);
    final bookmarks = widget.item is UserPost ? '1.3k' : _format((widget.item as PostModel).savesCount);
    final shares = widget.item is UserPost ? '100' : _format((widget.item as PostModel).sharesCount);

    Widget mediaWidget;
    Color? cardColor;
    EdgeInsets? imagePadding;
    BorderRadius? imageBorderRadius;

    if (widget.item is UserPost) {
      final post = widget.item as UserPost;
      if (post.videoPath != null) {
        mediaWidget = RunningVideoPlayer(
          file: File(post.videoPath!),
          height: widget.cardHeight - 44,
        );
      } else if (post.imagePath != null) {
        mediaWidget = Image.file(
          File(post.imagePath!),
          fit: BoxFit.cover,
          height: widget.cardHeight - 44,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => Container(
            height: widget.cardHeight - 44,
            color: const Color(0xFF2A2A2E),
            child: const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 32),
            ),
          ),
        );
      } else {
        mediaWidget = Container(height: widget.cardHeight - 44, color: const Color(0xFF2A2A2E));
      }
    } else {
      final post = widget.item as PostModel;
      
      if (post.id == 'social-4' || post.id == 'social-6') {
        cardColor = post.accentColor;
        imagePadding = const EdgeInsets.only(top: 6.0, left: 6.0, right: 6.0);
        imageBorderRadius = const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        );
      }

      Widget childWidget;
      if (post.mediaType == PostMediaType.video) {
        childWidget = RunningVideoPlayer(
          assetPath: post.mediaAssetPath,
          height: widget.cardHeight - 44,
        );
      } else if (post.mediaAssetPath == 'assets/images/outfit.png' ||
          post.mediaAssetPath == 'assets/images/jacket.png' ||
          post.mediaAssetPath == 'assets/images/meme.png') {
        childWidget = Container(
          height: widget.cardHeight - 44,
          width: double.infinity,
          color: const Color(0xFF2A2A2E),
        );
      } else {
        childWidget = Image.asset(
          post.mediaAssetPath,
          fit: BoxFit.cover,
          height: widget.cardHeight - 44,
          width: double.infinity,
        );
      }

      if (post.id == 'social-1') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildOutfitOverlay('Trend Huntss', true),
          ],
        );
      } else if (post.id == 'social-8') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildOutfitOverlay('Street Style', false),
          ],
        );
      } else if (post.id == 'social-3') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildMemeOverlay('rekha ji not so sanskari pics'),
          ],
        );
      } else if (post.id == 'social-7') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildMemeOverlay('flutter app look professional in 5 minutes'),
          ],
        );
      } else if (post.id == 'social-4') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildPandaOverlay('peace\nBRO!!'),
          ],
        );
      } else if (post.id == 'social-6') {
        mediaWidget = Stack(
          children: [
            childWidget,
            _buildPandaOverlay('chill\nTIME'),
          ],
        );
      } else {
        mediaWidget = childWidget;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: FeedCard(
        imageWidget: mediaWidget,
        likes: likes,
        bookmarks: bookmarks,
        shares: shares,
        cardColor: cardColor,
        imagePadding: imagePadding,
        imageBorderRadius: imageBorderRadius,
        isSaved: isSaved,
      ),
    );
  }

  Widget _buildOutfitOverlay(String title, bool arrow) {
    return Positioned.fill(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            if (arrow) ...[
              const SizedBox(height: 6),
              CustomPaint(
                size: const Size(60, 30),
                painter: ArrowPainter(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemeOverlay(String query) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF202124),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.menu, color: Color(0xFF9AA0A6), size: 10),
                Text(
                  'Google',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            Container(
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF303134),
                borderRadius: BorderRadius.circular(9),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF9AA0A6), size: 10),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      query,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.close, color: Color(0xFF9AA0A6), size: 10),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildMiniTab('All', active: false),
                _buildMiniTab('Images', active: true),
                _buildMiniTab('News', active: false),
                _buildMiniTab('Videos', active: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTab(String label, {required bool active}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: active ? const Color(0xFF8AB4F8) : const Color(0xFF9AA0A6),
          fontSize: 6.5,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildPandaOverlay(String text) {
    return Positioned(
      right: 14,
      top: 24,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.architectsDaughter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF18181A),
          height: 1.15,
        ),
      ),
    );
  }
}

// --- Arrow Painter for Card 1 & 8 ---
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(5.0, 10.0)
      ..quadraticBezierTo(25.0, 25.0, 45.0, 12.0);

    canvas.drawPath(path, paint);

    final arrowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final arrowPath = Path()
      ..moveTo(45.0, 12.0)
      ..lineTo(37.0, 10.0)
      ..lineTo(42.0, 18.0)
      ..close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
