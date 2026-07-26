import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/notification_tile.dart';
import '../../utils/translation_manager.dart';
import '../../utils/post_store.dart';

import '../../utils/notification_manager.dart';
import '../profile/profile_screen.dart';
import '../post_detail/post_detail_screen.dart';
import '../post/write_post_screen.dart';
import '../../models/post_model.dart';

class NotificationScreen extends StatefulWidget {
  final bool showBottomNav;
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const NotificationScreen({
    super.key,
    this.showBottomNav = true,
    this.showBackButton = true,
    this.onBackTap,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationManager.instance.markAllAsRead();
    });
  }

  Widget _buildVaultNotificationBanner() {
    return ValueListenableBuilder<List<UserPost>>(
      valueListenable: PostStore.instance.postsNotifier,
      builder: (context, postsList, _) {
        final savedUserPosts = postsList
            .where((p) => p.savedInProfile)
            .toList();
        if (savedUserPosts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_rounded,
                  color: Color(0xFF2ECC71),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vault Security: You have ${savedUserPosts.length} items saved privately. Only you can view them.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE5E5EA),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, _, _) {
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
                // ── Header ────────────────────────────────────────────────────
                _NotificationHeader(
                  statusBarHeight: statusBarHeight,
                  showBackButton: widget.showBackButton,
                  onBackTap: widget.onBackTap,
                ),

                _buildVaultNotificationBanner(),

                // ── Notification list ─────────────────────────────────────────
                Expanded(
                  child: ValueListenableBuilder<List<NotificationModel>>(
                    valueListenable:
                        NotificationManager.instance.notificationsNotifier,
                    builder: (context, notificationsList, _) {
                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: notificationsList.length,
                        itemBuilder: (context, index) {
                          final notif = notificationsList[index];
                          return NotificationTile(
                            notification: notif,
                            isAlternate: index.isEven,
                            onAccept: () {
                              NotificationManager.instance.acceptFriendRequest(notif);
                            },
                            onDeny: () {
                              NotificationManager.instance.denyFriendRequest(notif);
                            },
                            onTap: () {
                              bool pushedPost = false;
                              if (notif.postId != null) {
                                // Try finding UserPost
                                final idx = PostStore.instance.posts.indexWhere(
                                  (p) => p.id == notif.postId,
                                );
                                if (idx != -1) {
                                  final post = PostStore.instance.posts[idx];
                                  if (post.savedInProfile) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => WritePostScreen(
                                          isSaveItem: true,
                                          editingPost: post,
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(
                                          userPost: post,
                                        ),
                                      ),
                                    );
                                  }
                                  pushedPost = true;
                                } else {
                                  // Try finding PredefinedPost
                                  final pIdx = PostStore.predefinedPosts
                                      .indexWhere((p) => p.id == notif.postId);
                                  if (pIdx != -1) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PostDetailScreen(
                                          postModel:
                                              PostStore.predefinedPosts[pIdx],
                                        ),
                                      ),
                                    );
                                    pushedPost = true;
                                  }
                                }
                              }

                              if (!pushedPost) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      username: notif.username,
                                      avatarAssetPath: notif.avatarAssetPath,
                                      avatarInitial: notif.avatarInitial,
                                      avatarColor: notif.avatarColor,
                                      showBottomNav: false,
                                      showBackButton: true,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── Bottom navigation — bell tab active ───────────────────────────
            bottomNavigationBar: widget.showBottomNav
                ? AppBottomNavigation(
                    currentIndex: 2,
                    isAddMenuOpen: false,
                    onAddTap: () {},
                    onTabChanged: (index) {
                      if (index == 3) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfileScreen(),
                          ),
                        );
                      } else if (index == 0 || index == 1) {
                        Navigator.pop(context, index);
                      }
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _NotificationHeader extends StatelessWidget {
  final double statusBarHeight;
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const _NotificationHeader({
    required this.statusBarHeight,
    required this.showBackButton,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10,
        bottom: 12,
        left: 8,
        right: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back arrow
          if (showBackButton) ...[
            IconButton(
              onPressed: () {
                if (onBackTap != null) {
                  onBackTap!();
                } else if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
            const SizedBox(width: 4),
          ],
          if (!showBackButton) const SizedBox(width: 12),
          // Title
          Text(
            TranslationManager.t('notification'),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
