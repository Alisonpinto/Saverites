import 'dart:math' as math;
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
///
/// Contains the media (image or video) at the top,
/// and a light-grey reaction footer at the bottom.
class FeedCard extends StatelessWidget {
  final Widget imageWidget;
  final String likes;
  final String bookmarks;
  final String shares;
  final Color? cardColor;
  final EdgeInsets? imagePadding;
  final BorderRadius? imageBorderRadius;
  final bool isLiked;
  final bool isSaved;
  final VoidCallback? onLikeTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onShareTap;

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.likes,
    required this.bookmarks,
    required this.shares,
    this.cardColor,
    this.imagePadding,
    this.imageBorderRadius,
    this.isLiked = false,
    this.isSaved = false,
    this.onLikeTap,
    this.onSaveTap,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Media Area (Touches left/right edges, no padding, top rounded to 10px)
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
          child: imageWidget,
        ),
        // Bottom Action Strip (Height: 44px, background #E5E5E5, no gap, bottom rounded to 10px)
        Container(
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFE5E5E5),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(10),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Likes Section
              GestureDetector(
                onTap: onLikeTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BouncingIcon(
                      trigger: isLiked,
                      child: Icon(
                        isLiked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                        size: 18,
                        color: isLiked ? const Color(0xFF6B9BF7) : const Color(0xFF7C7C81),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      likes,
                      style: GoogleFonts.inter(
                        color: isLiked ? const Color(0xFF6B9BF7) : const Color(0xFF7C7C81),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Bookmarks Section
              GestureDetector(
                onTap: onSaveTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BouncingIcon(
                      trigger: isSaved,
                      child: Icon(
                        Icons.bookmark,
                        size: 18,
                        color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFF7C7C81),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bookmarks,
                      style: GoogleFonts.inter(
                        color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFF7C7C81),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Share Section
              GestureDetector(
                onTap: onShareTap,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: const Icon(
                        Icons.reply,
                        size: 22,
                        color: Color(0xFF7C7C81),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shares,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7C7C81),
                        fontSize: 14,
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
    );
  }
}
