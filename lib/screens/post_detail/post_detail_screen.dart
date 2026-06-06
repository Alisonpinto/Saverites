import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post_model.dart';

/// Full-screen detail view for a single post.
///
/// Opened by tapping any [PostCard] on the feed. Receives a [PostModel]
/// and renders the media, author info, title, description, URL, and
/// interactive action buttons.
///
/// Back navigation via the top-left arrow returns to the feed at the
/// same scroll position (Flutter preserves it automatically with push/pop).
class PostDetailScreen extends StatefulWidget {
  final PostModel post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _liked = false;
  bool _saved = false;
  late int _likes;
  late int _saves;

  @override
  void initState() {
    super.initState();
    _likes = widget.post.likesCount;
    _saves = widget.post.savesCount;
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
    final double screenHeight = MediaQuery.of(context).size.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double mediaHeight = screenHeight * 0.48;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF1C1C1E),
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Column(
          children: [
            // ── Media area ──────────────────────────────────────────────────
            Stack(
              children: [
                _MediaArea(
                  post: widget.post,
                  height: mediaHeight,
                ),

                // Back button — frosted circle overlay
                Positioned(
                  top: statusBarHeight + 12,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Bottom info card ────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF48484A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Author row ──────────────────────────────────────
                      _AuthorRow(post: widget.post),
                      const SizedBox(height: 20),

                      // ── Title ───────────────────────────────────────────
                      if (widget.post.title != null) ...[
                        Text(
                          widget.post.title!,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        // Placeholder title when no data yet
                        _PlaceholderLine(width: double.infinity, height: 26),
                        const SizedBox(height: 8),
                        _PlaceholderLine(width: 200, height: 26),
                        const SizedBox(height: 12),
                      ],

                      // ── Description ─────────────────────────────────────
                      if (widget.post.description != null) ...[
                        Text(
                          widget.post.description!,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFAEAEB2),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            height: 1.65,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        _PlaceholderLine(width: double.infinity, height: 14),
                        const SizedBox(height: 6),
                        _PlaceholderLine(width: double.infinity, height: 14),
                        const SizedBox(height: 6),
                        _PlaceholderLine(width: 160, height: 14),
                        const SizedBox(height: 16),
                      ],

                      // ── URL chip ────────────────────────────────────────
                      if (widget.post.url != null) ...[
                        _UrlChip(url: widget.post.url!),
                        const SizedBox(height: 16),
                      ],

                      const Divider(
                        color: Color(0xFF2C2C2E),
                        height: 32,
                        thickness: 1,
                      ),

                      // ── Action row ──────────────────────────────────────
                      _DetailActions(
                        liked: _liked,
                        saved: _saved,
                        likes: _likes,
                        saves: _saves,
                        shares: widget.post.sharesCount,
                        format: _format,
                        onLike: () => setState(() {
                          _liked = !_liked;
                          _likes += _liked ? 1 : -1;
                        }),
                        onSave: () => setState(() {
                          _saved = !_saved;
                          _saves += _saved ? 1 : -1;
                        }),
                        onShare: () {
                          // TODO: wire share sheet
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Media area ────────────────────────────────────────────────────────────────

class _MediaArea extends StatelessWidget {
  final PostModel post;
  final double height;

  const _MediaArea({required this.post, required this.height});

  @override
  Widget build(BuildContext context) {
    if (post.mediaAssetPath.isNotEmpty) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: Image.asset(
          post.mediaAssetPath,
          fit: BoxFit.cover,
        ),
      );
    }
    // Empty skeleton media area
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFF2A2A2E),
    );
  }
}

// ── Author row ────────────────────────────────────────────────────────────────

class _AuthorRow extends StatelessWidget {
  final PostModel post;

  const _AuthorRow({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF3A3A3C),
            image: post.avatarAssetPath != null
                ? DecorationImage(
                    image: AssetImage(post.avatarAssetPath!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: post.avatarAssetPath == null
              ? Center(
                  child: Text(
                    (post.username ?? 'U')[0].toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.username ?? 'Unknown user',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Posted a memory',
              style: GoogleFonts.inter(
                color: const Color(0xFF8E8E93),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── URL chip ──────────────────────────────────────────────────────────────────

class _UrlChip extends StatelessWidget {
  final String url;

  const _UrlChip({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Color(0xFF8E8E93), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              style: GoogleFonts.inter(
                color: const Color(0xFF6B9BF7),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF6B9BF7),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail action row ─────────────────────────────────────────────────────────

class _DetailActions extends StatelessWidget {
  final bool liked;
  final bool saved;
  final int likes;
  final int saves;
  final int shares;
  final String Function(int) format;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;

  const _DetailActions({
    required this.liked,
    required this.saved,
    required this.likes,
    required this.saves,
    required this.shares,
    required this.format,
    required this.onLike,
    required this.onSave,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn(
          icon: liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
          label: format(likes),
          active: liked,
          activeColor: const Color(0xFF6B9BF7),
          onTap: onLike,
        ),
        const SizedBox(width: 24),
        _Btn(
          icon: saved ? Icons.bookmark : Icons.bookmark_border,
          label: format(saves),
          active: saved,
          activeColor: const Color(0xFFBF5AF2),
          onTap: onSave,
        ),
        const SizedBox(width: 24),
        _Btn(
          iconWidget: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(math.pi),
            child: const Icon(Icons.reply, size: 22, color: Color(0xFFAEAEB2)),
          ),
          label: format(shares),
          active: false,
          activeColor: Colors.white,
          onTap: onShare,
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _Btn({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = active ? activeColor : const Color(0xFFAEAEB2);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          iconWidget ??
              Icon(icon, size: 22, color: active ? activeColor : const Color(0xFFAEAEB2)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton placeholder line ─────────────────────────────────────────────────

class _PlaceholderLine extends StatelessWidget {
  final double width;
  final double height;

  const _PlaceholderLine({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
