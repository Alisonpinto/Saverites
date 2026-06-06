import 'package:flutter/material.dart';

import '../models/post_model.dart';
import 'post_actions.dart';

/// Generic card shell used by every post in the masonry feed.
///
/// [post] supplies data (counts, accent colour, border-radius overrides).
/// [child] is the media content — built externally so that different card
/// types (image, video, custom overlay) can be composed freely without
/// coupling the card shell to any specific content type.
///
/// Adding a new content type later requires only a new [child] builder —
/// this widget and [PostActions] stay unchanged.
class PostCard extends StatelessWidget {
  final PostModel post;

  /// The media content area (image, video thumbnail, custom overlay, etc.).
  final Widget child;

  /// Optional share handler forwarded to [PostActions].
  final VoidCallback? onShare;

  /// Called when the user taps anywhere on the card.
  /// Typically used to push [PostDetailScreen].
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.post,
    required this.child,
    this.onShare,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Accent colour is used as the card background for cards that have
          // a coloured border (e.g. panda cards). Transparent by default.
          color: post.accentColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Media area ────────────────────────────────────────────────
            Padding(
              padding: post.mediaPadding ?? EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: post.mediaBorderRadius ??
                    const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                child: child,
              ),
            ),

            // ── Actions bar ───────────────────────────────────────────────
            PostActions(
              initialLikes: post.likesCount,
              initialSaves: post.savesCount,
              initialShares: post.sharesCount,
              onShare: onShare,
            ),
          ],
        ),
      ),
    );
  }
}
