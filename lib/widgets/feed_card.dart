import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A premium micro-animation wrapper that bounces its child when triggered.
class BouncingIcon extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const BouncingIcon({
    super.key,
    required this.child,
    required this.trigger,
  });

  @override
  State<BouncingIcon> createState() => _BouncingIconState();
}

class _BouncingIconState extends State<BouncingIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BouncingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// A reusable premium card styled for the Memoria masonry layout.
class FeedCard extends StatelessWidget {
  final Widget imageWidget;
  final String title;
  final String username;
  final String? avatarAssetPath;
  final String avatarInitial;
  final Color avatarColor;
  final String likes;
  final String bookmarks;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback? onLikeTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onImageTap;

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.title,
    required this.username,
    this.avatarAssetPath,
    required this.avatarInitial,
    required this.avatarColor,
    required this.likes,
    required this.bookmarks,
    this.isLiked = false,
    this.isSaved = false,
    this.onLikeTap,
    this.onSaveTap,
    this.onCardTap,
    this.onImageTap,
  });

  String _truncateTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'check out my new...';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length > 5) {
      return '${words.take(5).join(' ')}...';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCardTap,
      child: Container(
        width: 181,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SECTION 1 — MEDIA
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
              child: GestureDetector(
                onTap: onImageTap ?? onCardTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageWidget,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // SECTION 2 — TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _truncateTitle(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // SECTION 3 — ACTION FOOTER
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Avatar + Username in a capsule
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF292929), // Premium profile pill
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: CircleAvatar(
                              radius: 19, // 38x38 Circle
                              backgroundImage: avatarAssetPath != null
                                  ? AssetImage(avatarAssetPath!)
                                  : null,
                              backgroundColor: avatarColor,
                              child: avatarAssetPath == null
                                  ? Text(
                                      avatarInitial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Center: Like icon (Outline heart, white) + count
                  GestureDetector(
                    onTap: onLikeTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BouncingIcon(
                          trigger: isLiked,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey<bool>(isLiked),
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          likes,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Right: Save icon (Yellow Bookmark) + count
                  GestureDetector(
                    onTap: onSaveTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BouncingIcon(
                          trigger: isSaved,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              key: ValueKey<bool>(isSaved),
                              size: 28,
                              color: isSaved ? const Color(0xFFFFEE00) : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bookmarks,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
