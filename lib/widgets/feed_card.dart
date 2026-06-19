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

/// A stateful action button that scales down slightly on press for premium micro-interaction.
class _ActionButton extends StatefulWidget {
  final Widget iconWidget;
  final String count;
  final VoidCallback? onTap;
  final Color? textColor;

  const _ActionButton({
    required this.iconWidget,
    required this.count,
    this.onTap,
    this.textColor,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.9),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.iconWidget,
            const SizedBox(width: 4),
            Text(
              widget.count,
              style: GoogleFonts.inter(
                color: widget.textColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
  final String shares;
  final bool isLiked;
  final bool isSaved;
  final bool isSelected;
  final VoidCallback? onLikeTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onImageTap;

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.title,
    this.username = '',
    this.avatarAssetPath,
    this.avatarInitial = '?',
    this.avatarColor = Colors.grey,
    required this.likes,
    required this.bookmarks,
    required this.shares,
    this.isLiked = false,
    this.isSaved = false,
    this.isSelected = false,
    this.onLikeTap,
    this.onSaveTap,
    this.onShareTap,
    this.onCardTap,
    this.onImageTap,
  });

  String _formatTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
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
      child: Stack(
        children: [
          Container(
            // Removed fixed width: 181 to make the card fully responsive to column constraints
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A3B),
              borderRadius: BorderRadius.circular(10),
              border: isSelected ? Border.all(color: const Color(0xFFFAF096), width: 2) : null,
            ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SECTION 1 — MEDIA
            GestureDetector(
              onTap: onImageTap ?? onCardTap,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                child: imageWidget,
              ),
            ),
            const SizedBox(height: 16),
            
            // SECTION 2 — TITLE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _formatTitle(title),
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
            const SizedBox(height: 24),
            
            // SECTION 3 — ACTION FOOTER
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Heart + Count
                    _ActionButton(
                      iconWidget: BouncingIcon(
                        trigger: isLiked,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            key: ValueKey<bool>(isLiked),
                            size: 22,
                            color: isLiked ? const Color(0xFFE52E5E) : const Color(0xFFAEAEB2),
                          ),
                        ),
                      ),
                      count: likes,
                      textColor: isLiked ? const Color(0xFFE52E5E) : const Color(0xFFAEAEB2),
                      onTap: onLikeTap,
                    ),
                    const SizedBox(width: 12),

                    // Share + Count
                    _ActionButton(
                      iconWidget: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.141592653589793),
                        child: const Icon(
                          Icons.reply,
                          size: 22,
                          color: Color(0xFFAEAEB2),
                        ),
                      ),
                      count: shares,
                      textColor: const Color(0xFFAEAEB2),
                      onTap: onShareTap,
                    ),
                    const SizedBox(width: 12),

                    // Save + Count
                    _ActionButton(
                      iconWidget: BouncingIcon(
                        trigger: isSaved,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Icon(
                            isSaved ? Icons.bookmark : Icons.bookmark_border,
                            key: ValueKey<bool>(isSaved),
                            size: 22,
                            color: isSaved ? const Color(0xFFFFEE00) : const Color(0xFFAEAEB2),
                          ),
                        ),
                      ),
                      count: bookmarks,
                      textColor: isSaved ? const Color(0xFFFFEE00) : const Color(0xFFAEAEB2),
                      onTap: onSaveTap,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFAF096),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
