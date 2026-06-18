import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/post_model.dart';
import '../../utils/post_store.dart';
import '../../utils/share_helper.dart';
import '../../widgets/running_video_player.dart';
import '../../widgets/feed_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/rich_text_controller.dart';

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
  late int _likes;
  late int _saves;
  late int _shares;

  @override
  void initState() {
    super.initState();
    _likes = 0;
    _saves = widget.postModel?.savesCount ?? 0;
    _shares = widget.postModel?.sharesCount ?? 0;

    // Listen to changes in the global stores to update reactive status
    PostStore.instance.postsNotifier.addListener(_onStoreChanged);
    PostStore.instance.savedSocialPostIdsNotifier.addListener(_onStoreChanged);
    PostStore.instance.likedPostIdsNotifier.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    PostStore.instance.postsNotifier.removeListener(_onStoreChanged);
    PostStore.instance.savedSocialPostIdsNotifier.removeListener(_onStoreChanged);
    PostStore.instance.likedPostIdsNotifier.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // Helper getters to unify UserPost and PostModel properties
  UserPost? get currentUserPost {
    if (widget.userPost == null) return null;
    final posts = PostStore.instance.posts;
    final idx = posts.indexWhere((p) => p.id == widget.userPost!.id);
    if (idx != -1) return posts[idx];
    return widget.userPost;
  }

  String get id => widget.userPost?.id ?? widget.postModel!.id;
  String get title => currentUserPost?.title ?? widget.postModel?.title ?? '';
  String get description => currentUserPost?.body ?? widget.postModel?.description ?? '';
  List<RichStyle>? get charStyles => currentUserPost?.charStyles;
  String get username => widget.userPost != null ? (currentUserPost?.username ?? 'gangster_vagas') : (widget.postModel?.username ?? 'Unknown user');
  String? get avatarAssetPath => widget.userPost != null ? null : widget.postModel?.avatarAssetPath;
  String? get url => widget.userPost?.url ?? widget.postModel?.url;
  bool get _liked => PostStore.instance.likedPostIds.contains(id);

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

  void _sharePost() async {
    if (widget.userPost != null) {
      await ShareHelper.sharePost(
        title: title,
        description: description,
        url: url,
        localImagePath: widget.userPost!.imagePath,
        localVideoPath: widget.userPost!.videoPath,
        author: username,
      );
    } else if (widget.postModel != null) {
      await ShareHelper.sharePost(
        title: title,
        description: description,
        url: url,
        assetPath: widget.postModel!.mediaAssetPath,
        author: username,
      );
    }
  }

  Future<void> _launchUrl(String urlString) async {
    String normalized = urlString.trim();
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    final Uri parseUrl = Uri.parse(normalized);
    try {
      if (!await launchUrl(parseUrl, mode: LaunchMode.externalApplication)) {
        debugPrint("Could not launch $parseUrl");
      }
    } catch (e) {
      debugPrint("Error launching url: $e");
    }
  }

  void _showOptionsPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _buildOptionTile(
                  icon: Icons.share_outlined,
                  title: 'Share',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sharePost();
                  },
                ),
                _buildOptionTile(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  title: isSaved ? 'Unsave' : 'Save',
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleSave();
                  },
                ),
                _buildOptionTile(
                  icon: Icons.download_outlined,
                  title: 'Download',
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Downloading media...',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF6B9BF7),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide',
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Post hidden from your feed.',
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                        backgroundColor: const Color(0xFF48484A),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.flag_outlined,
                  title: 'Report',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportBottomSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReportBottomSheet() {
    String? selectedReason;
    final List<String> reasons = [
      'Harassment',
      'Hate speech',
      'Spam or misleading',
      'Self-harm',
      'Copyright violation',
      'Prohibited content',
      'Sharing personal info',
      'Other'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 12,
                  left: 20,
                  right: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48484A),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Report Post',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Why are you reporting this post?',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFAEAEB2),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...reasons.map((reason) {
                      final bool isSelected = selectedReason == reason;
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedReason = reason;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.white : const Color(0xFF48484A),
                                    width: isSelected ? 6 : 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                reason,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                
                                final String subject = Uri.encodeComponent('Memoria Report - $selectedReason');
                                final String postId = widget.userPost?.id ?? widget.postModel?.id ?? 'Unknown ID';
                                final String reportedAt = DateTime.now().toString();
                                final String bodyText = '''MEMORIA

Community Report Submission

Report Reason: $selectedReason

Post ID: $postId

Reported At: $reportedAt

This report was submitted from the Memoria mobile application.

Thank you for helping keep Memoria safe.

— Team Memoria''';
                                final String body = Uri.encodeComponent(bodyText);
                                final Uri emailUri = Uri.parse('mailto:etamax2026@gmail.com?subject=$subject&body=$body');

                                try {
                                  final bool launched = await launchUrl(emailUri);
                                  if (launched) {
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF1C1C1E),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: Text(
                                            'Thank You',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Text(
                                            'Thank you for helping improve Memoria and making our community safer for everyone.',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFAEAEB2),
                                              fontSize: 15,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Done',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } else {
                                    throw Exception('Could not launch email');
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Unable to open email app. Please contact support manually.',
                                          style: GoogleFonts.inter(color: Colors.white),
                                        ),
                                        backgroundColor: const Color(0xFFEB4335),
                                        duration: const Duration(seconds: 3),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF3A3A3C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Submit Report',
                          style: GoogleFonts.inter(
                            color: selectedReason == null ? const Color(0xFFAEAEB2) : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 24),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Background Media (InteractiveViewer) ────────────────────────
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: isVideo
                    ? RunningVideoPlayer(
                        file: widget.userPost?.videoPath != null
                            ? File(widget.userPost!.videoPath!)
                            : null,
                        assetPath: widget.postModel?.mediaAssetPath,
                      )
                    : (widget.userPost?.imagePath != null
                        ? Image.file(
                            File(widget.userPost!.imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF2A2A2E),
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                ),
                              );
                            },
                          )
                        : (widget.postModel?.mediaAssetPath != null && widget.postModel!.mediaAssetPath.isNotEmpty
                            ? Image.asset(
                                widget.postModel!.mediaAssetPath,
                                fit: BoxFit.contain,
                              )
                            : Container(
                                color: const Color(0xFF2A2A2E),
                                child: const Center(
                                  child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                                ),
                              ))),
              ),
            ),

            // ── Top Controls ────────────────────────────────────────────────
            Positioned(
              top: statusBarHeight + 12,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                ),
              ),
            ),
            Positioned(
              top: statusBarHeight + 12,
              right: 16,
              child: GestureDetector(
                onTap: _showOptionsPanel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert, color: Colors.white, size: 26),
                ),
              ),
            ),

            // ── Bottom Info Panel (DraggableScrollableSheet) ────────────────
            DraggableScrollableSheet(
              initialChildSize: 0.40,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
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
                          _buildDescriptionBlocks(description, charStyles),
                          const SizedBox(height: 16),
                        ],

                        // ── URL Chip (Grey, rounded box) ─────────────────────
                        if (url != null && url!.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => _launchUrl(url!),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
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
                              onTap: () => PostStore.instance.toggleLikedPost(id),
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: [
                                  BouncingIcon(
                                    trigger: _liked,
                                    child: Icon(
                                      _liked ? Icons.favorite : Icons.favorite_border,
                                      color: _liked ? const Color(0xFF6B9BF7) : const Color(0xFFAEAEB2),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _format(_liked ? _likes + 1 : _likes),
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
                                  BouncingIcon(
                                    trigger: isSaved,
                                    child: Icon(
                                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFFAEAEB2),
                                      size: 22,
                                    ),
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
                            GestureDetector(
                              onTap: _sharePost,
                              behavior: HitTestBehavior.opaque,
                              child: Row(
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Block parsing and building helpers
  Widget _buildDescriptionBlocks(String desc, List<RichStyle>? styles) {
    final blocks = parseBody(desc);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(blocks.length, (idx) {
        final block = blocks[idx];
        final sliceStyles = getSlice(styles, block.startIndex, block.endIndex);
        
        switch (block.type) {
          case BlockType.checklist:
            return _buildChecklistItemBlock(block, sliceStyles);
          case BlockType.document:
            return _buildDocumentBlock(block.meta?['name'] ?? 'Document.pdf');
          case BlockType.contact:
            return _buildContactBlock(block.meta?['details'] ?? 'Alex Rivers (+1 555-0199)');
          case BlockType.audio:
            return AudioPlayerBlock(durationText: block.meta?['duration'] ?? '0:45 min');
          case BlockType.code:
            return _buildCodeBlock(block.text, block.meta?['lang'] ?? 'dart');
          case BlockType.text:
            if (block.text.trim().isEmpty) {
              return const SizedBox(height: 8);
            }
            final isBullet = block.text.trim().startsWith('•') || block.text.trim().startsWith('-');
            return Padding(
              padding: EdgeInsets.only(bottom: 6, left: isBullet ? 12.0 : 0.0),
              child: RichTextController.buildRichText(
                block.text,
                sliceStyles,
                defaultStyle: GoogleFonts.inter(
                  color: const Color(0xFFAEAEB2),
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            );
        }
      }),
    );
  }

  List<RichStyle>? getSlice(List<RichStyle>? styles, int start, int end) {
    if (styles == null || styles.isEmpty) return null;
    if (start < 0 || end > styles.length || start > end) return null;
    return styles.sublist(start, end);
  }

  Widget _buildChecklistItemBlock(ContentBlock block, List<RichStyle>? sliceStyles) {
    final bool isTodo = block.text.contains('To-do item:');
    final String cleanText = block.text.replaceAll('To-do item:', '').trim();
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _toggleChecklistBlock(block),
            child: Container(
              margin: const EdgeInsets.only(top: 2, right: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: block.isChecked 
                  ? (isTodo ? const Color(0xFFBF5AF2) : const Color(0xFF6B9BF7)) 
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: block.isChecked 
                    ? Colors.transparent 
                    : const Color(0xFF8E8E93), 
                  width: 1.5
                ),
              ),
              child: block.isChecked 
                ? const Icon(Icons.check, color: Colors.black, size: 12) 
                : null,
            ),
          ),
          if (isTodo) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6, top: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFBF5AF2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFBF5AF2).withValues(alpha: 0.3), width: 0.5),
              ),
              child: Text(
                'TO-DO',
                style: GoogleFonts.inter(
                  color: const Color(0xFFBF5AF2),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          Expanded(
            child: Opacity(
              opacity: block.isChecked ? 0.45 : 1.0,
              child: RichTextController.buildRichText(
                cleanText,
                sliceStyles != null && sliceStyles.length > (block.text.length - cleanText.length)
                    ? sliceStyles.sublist(sliceStyles.length - cleanText.length)
                    : sliceStyles,
                defaultStyle: GoogleFonts.inter(
                  color: const Color(0xFFAEAEB2),
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  decoration: block.isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleChecklistBlock(ContentBlock block) {
    final currentText = description;
    final int targetPos = block.startIndex;
    if (targetPos + 3 <= currentText.length) {
      final prefix = currentText.substring(targetPos, targetPos + 3);
      String newPrefix = '';
      if (prefix == '[ ]') {
        newPrefix = '[x]';
      } else if (prefix == '[x]' || prefix == '[X]') {
        newPrefix = '[ ]';
      }
      
      if (newPrefix.isNotEmpty) {
        final newText = currentText.replaceRange(targetPos, targetPos + 3, newPrefix);
        if (widget.userPost != null) {
          PostStore.instance.updatePostText(widget.userPost!.id, newText, widget.userPost!.charStyles);
        }
      }
    }
  }

  Widget _buildDocumentBlock(String docName) {
    String type = docName.split('.').last.toUpperCase();
    IconData icon = Icons.description_outlined;
    Color color = const Color(0xFF8E8E93);
    if (type == 'PDF') {
      icon = Icons.picture_as_pdf_outlined;
      color = Colors.redAccent;
    } else if (type == 'DOC' || type == 'DOCX') {
      icon = Icons.description_outlined;
      color = const Color(0xFF6B9BF7);
    } else if (type == 'XLS' || type == 'XLSX') {
      icon = Icons.table_chart_outlined;
      color = Colors.greenAccent;
    } else if (type == 'ZIP' || type == 'RAR') {
      icon = Icons.folder_zip_outlined;
      color = Colors.amberAccent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => _openDocumentReader(docName),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$type Attachment • Tap to view',
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openDocumentReader(String docName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111216),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        double currentZoom = 100.0;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: const Color(0xFF1C1C1E),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            docName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20),
                          onPressed: () {
                            if (currentZoom > 50) {
                              setModalState(() => currentZoom -= 25);
                            }
                          },
                        ),
                        Text(
                          '${currentZoom.toInt()}%',
                          style: GoogleFonts.robotoMono(color: Colors.white70, fontSize: 13),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20),
                          onPressed: () {
                            if (currentZoom < 200) {
                              setModalState(() => currentZoom += 25);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: EdgeInsets.all(24 * (currentZoom / 100)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  docName.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontSize: 18 * (currentZoom / 100),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Divider(color: Colors.black12, thickness: 1.5, height: 24 * (currentZoom / 100)),
                                Text(
                                  'MEMORIA VAULT FILE\nClassification: Confidential\n\n'
                                  'This document is stored as a reference attachment within the Memoria vault.\n\n'
                                  'Security Guidelines:\n'
                                  '• Local files are encrypted via local keys.\n'
                                  '• External transmission requires user authentication.\n\n'
                                  'Notes:\n'
                                  'Ensure documents are classified properly and backups are updated.',
                                  style: GoogleFonts.inter(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    fontSize: 13 * (currentZoom / 100),
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 80),
                                Center(
                                  child: Text(
                                    '- Page 1 of 1 -',
                                    style: GoogleFonts.inter(color: Colors.black38, fontSize: 10 * (currentZoom / 100)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactBlock(String contactDetails) {
    final match = RegExp(r'^([^\(]+)(?:\((.+)\))?$').firstMatch(contactDetails);
    String name = contactDetails;
    String phone = 'No number';
    if (match != null) {
      name = match.group(1)!.trim();
      phone = (match.group(2) ?? '').trim();
    }
    
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';

    void performCall() async {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+]'), '');
      final Uri telUri = Uri.parse('tel:$cleanPhone');
      try {
        if (!await launchUrl(telUri)) {
          debugPrint("Could not launch tel:$cleanPhone");
        }
      } catch (e) {
        debugPrint("Error making call: $e");
      }
    }

    void performMessage() async {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d\+]'), '');
      final Uri smsUri = Uri.parse('sms:$cleanPhone');
      try {
        if (!await launchUrl(smsUri)) {
          debugPrint("Could not launch sms:$cleanPhone");
        }
      } catch (e) {
        debugPrint("Error sending message: $e");
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFBF5AF2), Color(0xFF6B9BF7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: Color(0xFF6B9BF7), size: 20),
              onPressed: performCall,
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFBF5AF2), size: 20),
              onPressed: performMessage,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String code, String lang) {
    void copyCode() {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF2C2C2E),
          content: Text(
            'Copied to Clipboard!',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
    }

    TextSpan highlightCode(String rawCode) {
      final keywords = RegExp(r'\b(class|import|void|final|const|return|if|else|var|let|function|def|int|double|String|bool|Map|List|static|override)\b');
      final comments = RegExp(r'(//.*|#.*)');
      final strings = RegExp(r'(\u0022[^\u0022]*\u0022|\u0027[^\u0027]*\u0027)');
      
      final List<TextSpan> spans = [];
      final lines = rawCode.split('\n');
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        int currentPos = 0;
        
        final List<RegExpMatch> matches = [];
        matches.addAll(keywords.allMatches(line));
        matches.addAll(comments.allMatches(line));
        matches.addAll(strings.allMatches(line));
        matches.sort((a, b) => a.start.compareTo(b.start));
        
        final List<RegExpMatch> cleanMatches = [];
        int lastEnd = 0;
        for (final match in matches) {
          if (match.start >= lastEnd) {
            cleanMatches.add(match);
            lastEnd = match.end;
          }
        }

        for (final match in cleanMatches) {
          if (match.start > currentPos) {
            spans.add(TextSpan(text: line.substring(currentPos, match.start), style: const TextStyle(color: Color(0xFFDCDCAA))));
          }
          
          final textMatch = line.substring(match.start, match.end);
          Color c = Colors.white;
          if (keywords.hasMatch(textMatch)) {
            c = const Color(0xFF569CD6);
          } else if (comments.hasMatch(textMatch)) {
            c = const Color(0xFF6A9955);
          } else if (strings.hasMatch(textMatch)) {
            c = const Color(0xFFCE9178);
          }
          spans.add(TextSpan(text: textMatch, style: TextStyle(color: c)));
          currentPos = match.end;
        }
        
        if (currentPos < line.length) {
          spans.add(TextSpan(text: line.substring(currentPos), style: const TextStyle(color: Color(0xFFDCDCAA))));
        }
        
        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n'));
        }
      }
      return TextSpan(children: spans);
    }

    final lines = code.split('\n');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2D2D2D),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  ...List.generate(3, (idx) {
                    final color = idx == 0 ? Colors.redAccent : (idx == 1 ? Colors.amberAccent : Colors.greenAccent);
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    lang.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: copyCode,
                    child: Row(
                      children: [
                        const Icon(Icons.copy, color: Colors.white60, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: GoogleFonts.inter(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(lines.length, (index) {
                      return SizedBox(
                        height: 18,
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.robotoMono(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText.rich(
                        highlightCode(code),
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
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

// Additional Classes
enum BlockType { text, checklist, document, contact, audio, code }

class ContentBlock {
  final BlockType type;
  final String text;
  final bool isChecked;
  final Map<String, String>? meta;
  final int startIndex;
  final int endIndex;

  ContentBlock({
    required this.type,
    required this.text,
    this.isChecked = false,
    this.meta,
    required this.startIndex,
    required this.endIndex,
  });
}

List<ContentBlock> parseBody(String body) {
  final List<ContentBlock> blocks = [];
  final List<String> lines = body.split('\n');
  
  bool inCodeBlock = false;
  String codeLanguage = '';
  List<String> codeLines = [];
  int codeStartIndex = 0;
  
  int currentCharIndex = 0;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final int lineStart = currentCharIndex;
    final int lineEnd = currentCharIndex + line.length;
    
    if (line.trim().startsWith('```')) {
      if (inCodeBlock) {
        blocks.add(ContentBlock(
          type: BlockType.code,
          text: codeLines.join('\n'),
          meta: {'lang': codeLanguage},
          startIndex: codeStartIndex,
          endIndex: lineEnd,
        ));
        inCodeBlock = false;
        codeLines = [];
      } else {
        inCodeBlock = true;
        codeStartIndex = lineStart;
        codeLanguage = line.trim().substring(3).trim();
        if (codeLanguage.isEmpty) codeLanguage = 'code';
      }
      currentCharIndex += line.length + 1;
      continue;
    }
    
    if (inCodeBlock) {
      codeLines.add(line);
      currentCharIndex += line.length + 1;
      continue;
    }
    
    final checklistMatch = RegExp(r'^\[([ xX])\]\s*(.*)$').firstMatch(line);
    if (checklistMatch != null) {
      final String checkChar = checklistMatch.group(1)!;
      final String content = checklistMatch.group(2)!;
      final bool isChecked = checkChar.toLowerCase() == 'x';
      
      blocks.add(ContentBlock(
        type: BlockType.checklist,
        text: content,
        isChecked: isChecked,
        startIndex: lineStart,
        endIndex: lineEnd,
      ));
      currentCharIndex += line.length + 1;
      continue;
    }
    
    final docMatch = RegExp(r'^\[Document:\s*([^\]]+)\]$').firstMatch(line);
    if (docMatch != null) {
      final String docName = docMatch.group(1)!;
      blocks.add(ContentBlock(
        type: BlockType.document,
        text: line,
        meta: {'name': docName},
        startIndex: lineStart,
        endIndex: lineEnd,
      ));
      currentCharIndex += line.length + 1;
      continue;
    }
    
    final contactMatch = RegExp(r'^\[Contact:\s*([^\]]+)\]$').firstMatch(line);
    if (contactMatch != null) {
      final String contactDetails = contactMatch.group(1)!;
      blocks.add(ContentBlock(
        type: BlockType.contact,
        text: line,
        meta: {'details': contactDetails},
        startIndex: lineStart,
        endIndex: lineEnd,
      ));
      currentCharIndex += line.length + 1;
      continue;
    }
    
    final audioMatch = RegExp(r'^\[(?:Audio Recording|Audio):\s*([^\]]+)\]$').firstMatch(line);
    if (audioMatch != null) {
      final String audioDetails = audioMatch.group(1)!;
      blocks.add(ContentBlock(
        type: BlockType.audio,
        text: line,
        meta: {'duration': audioDetails},
        startIndex: lineStart,
        endIndex: lineEnd,
      ));
      currentCharIndex += line.length + 1;
      continue;
    }
    
    blocks.add(ContentBlock(
      type: BlockType.text,
      text: line,
      startIndex: lineStart,
      endIndex: lineEnd,
    ));
    currentCharIndex += line.length + 1;
  }
  
  if (inCodeBlock) {
    blocks.add(ContentBlock(
      type: BlockType.code,
      text: codeLines.join('\n'),
      meta: {'lang': codeLanguage},
      startIndex: codeStartIndex,
      endIndex: currentCharIndex,
    ));
  }
  
  return blocks;
}

class AudioPlayerBlock extends StatefulWidget {
  final String durationText;
  const AudioPlayerBlock({super.key, required this.durationText});

  @override
  State<AudioPlayerBlock> createState() => _AudioPlayerBlockState();
}

class _AudioPlayerBlockState extends State<AudioPlayerBlock> {
  bool _isPlaying = false;
  int _elapsedSeconds = 0;
  int _totalSeconds = 45;
  Timer? _playbackTimer;

  @override
  void initState() {
    super.initState();
    final cleanText = widget.durationText.replaceAll('min', '').trim();
    final parts = cleanText.split(':');
    if (parts.length == 2) {
      final int m = int.tryParse(parts[0]) ?? 0;
      final int s = int.tryParse(parts[1]) ?? 45;
      _totalSeconds = (m * 60) + s;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _playbackTimer?.cancel();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      _playbackTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_elapsedSeconds >= _totalSeconds) {
          _playbackTimer?.cancel();
          setState(() {
            _isPlaying = false;
            _elapsedSeconds = 0;
          });
        } else {
          setState(() {
            _elapsedSeconds++;
          });
        }
      });
    }
  }

  String _formatDuration(int sec) {
    final int m = sec ~/ 60;
    final int s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double percent = _totalSeconds > 0 ? (_elapsedSeconds / _totalSeconds) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Audio Note',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${_formatDuration(_elapsedSeconds)} / ${_formatDuration(_totalSeconds)}',
                        style: GoogleFonts.robotoMono(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final barCount = (width / 6).floor() > 0 ? (width / 6).floor() : 1;
                      return SizedBox(
                        height: 24,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(barCount, (index) {
                            final double progressPercent = index / barCount;
                            final bool isFilled = progressPercent <= percent;
                            final double heightVal = 4.0 + (1.0 + math.sin(index.toDouble() * 0.5)) * 8.0;
                            
                            return Container(
                              width: 3,
                              height: heightVal,
                              decoration: BoxDecoration(
                                color: isFilled 
                                    ? const Color(0xFF6B9BF7) 
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            );
                          }),
                        ),
                      );
                    },
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
