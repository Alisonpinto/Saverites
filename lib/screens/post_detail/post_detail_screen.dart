import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post_model.dart';
import '../../utils/post_store.dart';
import '../../widgets/running_video_player.dart';

/// Unified full-screen detail view for any post (user-created or predefined social post).
///
/// Styled matching the premium Figma dark mode specification.
class PostDetailScreen extends StatefulWidget {
  final UserPost? userPost;
  final PostModel? postModel;

  const PostDetailScreen({
    super.key,
    this.userPost,
    this.postModel,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _liked = false;
  late int _likes;
  late int _saves;
  late int _shares;

  @override
  void initState() {
    super.initState();
    _likes = widget.postModel?.likesCount ?? 1000;
    _saves = widget.postModel?.savesCount ?? 1300;
    _shares = widget.postModel?.sharesCount ?? 100;

    // Listen to changes in the global stores to update reactive status
    PostStore.instance.postsNotifier.addListener(_onStoreChanged);
    PostStore.instance.savedSocialPostIdsNotifier.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    PostStore.instance.postsNotifier.removeListener(_onStoreChanged);
    PostStore.instance.savedSocialPostIdsNotifier.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Helper getters to unify UserPost and PostModel properties
  String get id => widget.userPost?.id ?? widget.postModel!.id;
  String get title => widget.userPost?.title ?? widget.postModel?.title ?? '';
  String get description => widget.userPost?.body ?? widget.postModel?.description ?? '';
  String get username => widget.userPost != null ? 'gangster_vagas' : (widget.postModel?.username ?? 'Unknown user');
  String? get avatarAssetPath => widget.userPost != null ? null : widget.postModel?.avatarAssetPath;
  String? get url => widget.postModel?.url;

  bool get isSaved {
    if (widget.userPost != null) {
      final posts = PostStore.instance.posts;
      final idx = posts.indexWhere((p) => p.id == widget.userPost!.id);
      if (idx != -1) {
        return posts[idx].savedInProfile;
      }
      return widget.userPost!.savedInProfile;
    } else {
      return PostStore.instance.savedSocialPostIds.contains(widget.postModel!.id);
    }
  }

  bool get isVideo {
    return widget.userPost?.videoPath != null ||
        widget.postModel?.mediaType == PostMediaType.video;
  }

  String _format(int count) {
    if (count >= 1000) {
      final double v = count / 1000;
      return '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  void _toggleSave() {
    if (widget.userPost != null) {
      PostStore.instance.toggleSavedInProfile(id);
    } else {
      PostStore.instance.toggleSavedSocialPost(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double mediaHeight = screenHeight * 0.48;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF7C7C81),
                Color(0xFF1A1A1B),
                Color(0xFF000000),
              ],
              stops: [0.0, 0.24, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              // ── Media Area ──────────────────────────────────────────────────
              Stack(
                children: [
                  SizedBox(
                    height: mediaHeight,
                    width: double.infinity,
                    child: isVideo
                        ? RunningVideoPlayer(
                            file: widget.userPost?.videoPath != null
                                ? File(widget.userPost!.videoPath!)
                                : null,
                            assetPath: widget.postModel?.mediaAssetPath,
                            height: mediaHeight,
                          )
                        : (widget.userPost?.imagePath != null
                            ? Image.file(
                                File(widget.userPost!.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFF2A2A2E),
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.white54, size: 48),
                                    ),
                                  );
                                },
                              )
                            : (widget.postModel?.mediaAssetPath != null &&
                                    widget.postModel!.mediaAssetPath.isNotEmpty
                                ? (widget.postModel!.mediaAssetPath == 'assets/images/outfit.png' ||
                                        widget.postModel!.mediaAssetPath == 'assets/images/jacket.png' ||
                                        widget.postModel!.mediaAssetPath == 'assets/images/meme.png'
                                    ? Container(
                                        color: const Color(0xFF2A2A2E),
                                        child: const Center(
                                          child: Icon(Icons.image_outlined,
                                              color: Colors.white24, size: 48),
                                        ),
                                      )
                                    : Image.asset(
                                        widget.postModel!.mediaAssetPath,
                                        fit: BoxFit.cover,
                                      ))
                                : Container(
                                    color: const Color(0xFF2A2A2E),
                                    child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.white54, size: 48),
                                    ),
                                  ))),
                  ),

                  // Back button — plain white arrow overlay
                  Positioned(
                    top: statusBarHeight + 12,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Bottom info card (Solid Black, Figma design spec) ───────────
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.black,
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
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF3A3A3C),
                                image: avatarAssetPath != null
                                    ? DecorationImage(
                                        image: AssetImage(avatarAssetPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: avatarAssetPath == null
                                  ? Center(
                                      child: Text(
                                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              username,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Title (All Caps, Bold, White) ────────────────────
                        if (title.isNotEmpty) ...[
                          Text(
                            title.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── Description (Inter Light w300, Silver) ────────────
                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFAEAEB2),
                              fontSize: 15,
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── URL Chip (Grey, rounded box) ─────────────────────
                        if (url != null && url!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              url!,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        const Divider(
                          color: Color(0xFF2C2C2E),
                          height: 32,
                          thickness: 1,
                        ),

                        // ── Action Row (Footer with reaction counts) ──────────
                        Row(
                          children: [
                            // Likes
                            GestureDetector(
                              onTap: () => setState(() {
                                _liked = !_liked;
                                _likes += _liked ? 1 : -1;
                              }),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  Icon(
                                    _liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
                                    color: _liked ? const Color(0xFF6B9BF7) : const Color(0xFFAEAEB2),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _format(_likes),
                                    style: GoogleFonts.inter(
                                      color: _liked ? const Color(0xFF6B9BF7) : const Color(0xFFAEAEB2),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Bookmarks / Saves
                            GestureDetector(
                              onTap: _toggleSave,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  Icon(
                                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFFAEAEB2),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _format(isSaved ? _saves + 1 : _saves),
                                    style: GoogleFonts.inter(
                                      color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFFAEAEB2),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Shares
                            Row(
                              children: [
                                Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(math.pi),
                                  child: const Icon(
                                    Icons.reply,
                                    color: Color(0xFFAEAEB2),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _format(_shares),
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFAEAEB2),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
