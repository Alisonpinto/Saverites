import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/translation_manager.dart';
import '../../models/post_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/shimmer_container.dart';
import '../../widgets/feed_card.dart';
import '../../widgets/running_video_player.dart';
import 'settings_screen.dart';
import '../post/write_post_screen.dart';
import '../notifications/notification_screen.dart';
import '../../utils/post_store.dart';
import '../post_detail/post_detail_screen.dart';
import '../../utils/rich_text_controller.dart';


// ─────────────────────────────────────────────
//  ProfileScreen – root
// ─────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final String? username;
  final String? avatarAssetPath;
  final String? avatarInitial;
  final Color? avatarColor;
  final bool showBottomNav;
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const ProfileScreen({
    super.key,
    this.username,
    this.avatarAssetPath,
    this.avatarInitial,
    this.avatarColor,
    this.showBottomNav = true,
    this.showBackButton = true,
    this.onBackTap,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  int _activeTab = 0;
  bool _fabExpanded = false;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  final TextEditingController _searchController = TextEditingController();
  String _profileSearchQuery = "";
  String _activeCategoryChip = "Recent";

  String _getVaultReminder(List<UserPost> saves) {
    if (saves.isEmpty) {
      return "Start saving things you like to your vault.";
    }
    final docs = saves.where((p) => p.type == 'document').toList();
    if (docs.isNotEmpty) {
      return "You saved a document recently. Review it in Self Save.";
    }
    final checklists = saves.where((p) => p.type == 'checklist').toList();
    if (checklists.isNotEmpty) {
      return "Remember to check off items on your active checklist!";
    }
    final contacts = saves.where((p) => p.type == 'contact').toList();
    if (contacts.isNotEmpty) {
      return "You have saved contacts in your vault. Keep them secure.";
    }
    return "You've saved ${saves.length} private items. Keep organizing your thoughts!";
  }

  Widget _buildCategoryChips() {
    final categories = ['Recent', 'Documents', 'Media', 'Contacts', 'Audio', 'Ideas'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _activeCategoryChip == cat;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _activeCategoryChip = cat;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0xFF2D2D30),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.black : const Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── FAB animation controllers ──────────────
  late AnimationController _fabController;
  late Animation<double> _fabRotation;
  late Animation<double> _fab1SlideY;
  late Animation<double> _fab2SlideY;
  late Animation<double> _fab1Opacity;
  late Animation<double> _fab2Opacity;
  late Animation<double> _fab1Scale;
  late Animation<double> _fab2Scale;

  // Mock saves are now reactively queried from the central PostStore.instance

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fabRotation = Tween<double>(begin: 0, end: 0.125).animate(
      CurvedAnimation(parent: _fabController, curve: Curves.easeInOutCubic),
    );
    _fab1SlideY = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );
    _fab2SlideY = Tween<double>(begin: 24, end: 0).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic)),
    );
    _fab1Opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.0, 0.6)),
    );
    _fab2Opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.1, 0.7)),
    );
    _fab1Scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );
    _fab2Scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _fabController, curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic)),
    );

    _scrollController.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollController.offset);
    });

    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkConnectivity();
    });

    PostStore.instance.postsNotifier.addListener(_onPostsChanged);
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _fabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    PostStore.instance.postsNotifier.removeListener(_onPostsChanged);
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != online) {
        setState(() {
          _isOnline = online;
        });
      }
    } catch (_) {
      if (mounted && _isOnline != false) {
        setState(() {
          _isOnline = false;
        });
      }
    }
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabController.forward();
    } else {
      _fabController.reverse();
    }
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, lang, v) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF1A1A1B),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            body: Stack(
              children: [
                // ── Gradient background ───────────────────────────
                Positioned.fill(
                  child: Container(
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
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      // Sticky Header Row (placed directly on gradient background)
                      Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.of(context).padding.top > 0
                              ? MediaQuery.of(context).padding.top
                              : 10,
                          bottom: 12,
                          left: 8,
                          right: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                if (widget.onBackTap != null) {
                                  widget.onBackTap!();
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
                            Text(
                              'Profile',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (ctx, anim, x) => const SettingsScreen(),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.04),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                      child: child,
                                    ),
                                  ),
                                  transitionDuration: const Duration(milliseconds: 450),
                                ),
                              ),
                              icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),

                              // Avatar + Profile Details Row
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Transform.translate(
                                      offset: Offset(0, -(_scrollOffset * 0.04).clamp(-8.0, 8.0)),
                                      child: SizedBox(
                                        width: 130,
                                        height: 130,
                                        child: widget.avatarAssetPath != null || widget.avatarInitial != null
                                            ? Container(
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: widget.avatarColor ?? const Color(0xFF7B61FF),
                                                  image: widget.avatarAssetPath != null
                                                      ? DecorationImage(
                                                          image: AssetImage(widget.avatarAssetPath!),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                                ),
                                                alignment: Alignment.center,
                                                child: widget.avatarAssetPath == null && widget.avatarInitial != null
                                                    ? Text(
                                                        widget.avatarInitial!.toUpperCase(),
                                                        style: GoogleFonts.inter(
                                                          color: Colors.white,
                                                          fontSize: 48,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      )
                                                    : null,
                                              )
                                            : const _AnimatedAvatar(size: 130),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.username ?? 'gangster_vagas',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '20 june 024',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF7C7C81),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '6.7k',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'likes',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF7C7C81),
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 24),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '170',
                                                    style: GoogleFonts.inter(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'post',
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF7C7C81),
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
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Search field (Only search field has rounded border)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _PremiumSearchBar(
                                  controller: _searchController,
                                  onChanged: (val) {
                                    setState(() {
                                      _profileSearchQuery = val;
                                    });
                                  },
                                  onClear: () {
                                    _searchController.clear();
                                    setState(() {
                                      _profileSearchQuery = "";
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Tabs
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _PremiumTabBar(
                                  activeTab: _activeTab,
                                  onTabChanged: (i) => setState(() => _activeTab = i),
                                ),
                              ),

                              if (_activeTab == 1) ...[
                                const SizedBox(height: 16),
                                _buildCategoryChips(),
                              ],

                              const SizedBox(height: 18),

                              // Grid — Tab 0 shows saved PostModel, Tab 1 shows saved UserPost
                              _buildProfileGrid(),

                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Blur overlay ──────────────────────────────────
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_fabExpanded,
                    child: AnimatedOpacity(
                      opacity: _fabExpanded ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      child: GestureDetector(
                        onTap: _closeFab,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── FAB overlay ───────────────────────────────────
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Action: Write a Post
                      AnimatedBuilder(
                        animation: _fabController,
                        builder: (ctx, ab) => IgnorePointer(
                          ignoring: !_fabExpanded,
                          child: Opacity(
                            opacity: _fab1Opacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _fab1SlideY.value),
                              child: Transform.scale(
                                scale: _fab1Scale.value,
                                child: _FabAction(
                                  label: 'Write a Post',
                                  icon: Icons.article_outlined,
                                  onTap: () {
                                    _closeFab();
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => const WritePostScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          final slideAnimation = Tween<Offset>(
                                            begin: const Offset(0.0, 0.08),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          );
                                          final fadeAnimation = Tween<double>(
                                            begin: 0.0,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeIn,
                                            ),
                                          );
                                          return FadeTransition(
                                            opacity: fadeAnimation,
                                            child: SlideTransition(
                                              position: slideAnimation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Action: Save a Item
                      AnimatedBuilder(
                        animation: _fabController,
                        builder: (ctx, wb) => IgnorePointer(
                          ignoring: !_fabExpanded,
                          child: Opacity(
                            opacity: _fab2Opacity.value,
                            child: Transform.translate(
                              offset: Offset(0, _fab2SlideY.value),
                              child: Transform.scale(
                                scale: _fab2Scale.value,
                                child: _FabAction(
                                  label: 'Save a Item',
                                  icon: Icons.save_outlined,
                                  onTap: () {
                                    _closeFab();
                                    Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => const WritePostScreen(isSaveItem: true),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          final slideAnimation = Tween<Offset>(
                                            begin: const Offset(0.0, 0.08),
                                            end: Offset.zero,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeOutCubic,
                                            ),
                                          );
                                          final fadeAnimation = Tween<double>(
                                            begin: 0.0,
                                            end: 1.0,
                                          ).animate(
                                            CurvedAnimation(
                                              parent: animation,
                                              curve: Curves.easeIn,
                                            ),
                                          );
                                          return FadeTransition(
                                            opacity: fadeAnimation,
                                            child: SlideTransition(
                                              position: slideAnimation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        transitionDuration: const Duration(milliseconds: 400),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // FAB main button
                      AnimatedBuilder(
                        animation: _fabRotation,
                        builder: (_, child) => Transform.rotate(
                          angle: _fabRotation.value * 2 * math.pi,
                          child: child,
                        ),
                        child: GestureDetector(
                          onTap: _toggleFab,
                          child: _FloatingFab(expanded: _fabExpanded),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: widget.showBottomNav
                ? AppBottomNavigation(
                    currentIndex: 3,
                    onTabChanged: (index) {
                      if (index == 2) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationScreen()),
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

  Widget _buildProfileGrid() {
    final bool isMyProfile = widget.username == null || widget.username == 'gangster_vagas';
    final query = _profileSearchQuery.toLowerCase().trim();

    if (_activeTab == 0) {
      if (isMyProfile) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: PostStore.instance.savedSocialPostIdsNotifier,
          builder: (context, savedSocialIds, _) {
            var savedPredefined = PostStore.predefinedPosts
                .where((p) => savedSocialIds.contains(p.id))
                .toList();

            if (query.isNotEmpty) {
              savedPredefined = savedPredefined.where((p) {
                return (p.title?.toLowerCase().contains(query) ?? false) ||
                       (p.description?.toLowerCase().contains(query) ?? false) ||
                       (p.username?.toLowerCase().contains(query) ?? false) ||
                       (p.url?.toLowerCase().contains(query) ?? false);
              }).toList();
            }

            return _ProfileMasonryGrid(items: savedPredefined, isOnline: _isOnline);
          },
        );
      } else {
        var friendPosts = PostStore.predefinedPosts.where((p) => p.username == widget.username).toList();
        if (query.isNotEmpty) {
          friendPosts = friendPosts.where((p) {
            return (p.title?.toLowerCase().contains(query) ?? false) ||
                   (p.description?.toLowerCase().contains(query) ?? false) ||
                   (p.url?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
        return _ProfileMasonryGrid(items: friendPosts, isOnline: _isOnline);
      }
    } else {
      if (isMyProfile) {
        return ValueListenableBuilder<List<UserPost>>(
          valueListenable: PostStore.instance.postsNotifier,
          builder: (context, postsList, _) {
            var savedUserPosts = postsList.where((p) => p.savedInProfile).toList();

            // 1. Filter by category chip
            if (_activeCategoryChip == 'Documents') {
              savedUserPosts = savedUserPosts.where((p) => p.type == 'document').toList();
            } else if (_activeCategoryChip == 'Media') {
              savedUserPosts = savedUserPosts.where((p) => p.type == 'image' || p.type == 'video').toList();
            } else if (_activeCategoryChip == 'Contacts') {
              savedUserPosts = savedUserPosts.where((p) => p.type == 'contact').toList();
            } else if (_activeCategoryChip == 'Audio') {
              savedUserPosts = savedUserPosts.where((p) => p.type == 'audio').toList();
            } else if (_activeCategoryChip == 'Ideas') {
              savedUserPosts = savedUserPosts.where((p) => p.type == 'text' || p.type == 'checklist' || p.type == 'code' || p.type == 'link').toList();
            }

            // 2. Filter by search query
            if (query.isNotEmpty) {
              savedUserPosts = savedUserPosts.where((p) {
                return p.title.toLowerCase().contains(query) ||
                       p.body.toLowerCase().contains(query) ||
                       (p.contactName?.toLowerCase().contains(query) ?? false) ||
                       (p.contactPhone?.toLowerCase().contains(query) ?? false) ||
                       (p.filePath?.toLowerCase().contains(query) ?? false) ||
                       (p.url?.toLowerCase().contains(query) ?? false);
              }).toList();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (savedUserPosts.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getVaultReminder(savedUserPosts),
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
                  ),
                  const SizedBox(height: 8),
                ],
                _ProfileMasonryGrid(items: savedUserPosts, isOnline: _isOnline),
              ],
            );
          },
        );
      } else {
        var friendPosts = PostStore.predefinedPosts.where((p) => p.username == widget.username).toList();
        if (query.isNotEmpty) {
          friendPosts = friendPosts.where((p) {
            return (p.title?.toLowerCase().contains(query) ?? false) ||
                   (p.description?.toLowerCase().contains(query) ?? false) ||
                   (p.url?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
        return _ProfileMasonryGrid(items: friendPosts, isOnline: _isOnline);
      }
    }
  }
}



// _PremiumProfileInfo is now inlined inside the top card — kept as no-op placeholder


// ─────────────────────────────────────────────
//  Animated Illustrated Avatar
//  Open Peeps-inspired minimal SVG avatar
//  with continuously animating hair
// ─────────────────────────────────────────────
class _AnimatedAvatar extends StatefulWidget {
  final double size;
  const _AnimatedAvatar({this.size = 88});

  @override
  State<_AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<_AnimatedAvatar>
    with TickerProviderStateMixin {
  late AnimationController _hairController;
  late AnimationController _floatController;
  late Animation<double> _hairSwayAnim;
  late Animation<double> _hairBreathAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    // Hair sway: gentle left-right, period 3.5s
    _hairController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _hairSwayAnim = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _hairController, curve: Curves.easeInOutSine),
    );

    _hairBreathAnim = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _hairController, curve: Curves.easeInOutSine),
    );

    // Floating: tiny vertical bob, period 4s
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _hairController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hairController, _floatController]),
      builder: (ctx, xb) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _AvatarPainter(
                hairSway: _hairSwayAnim.value,
                hairBreath: _hairBreathAnim.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final double hairSway;
  final double hairBreath;

  const _AvatarPainter({
    required this.hairSway,
    required this.hairBreath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Outline paint ────────────────────────────
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final skinPaint = Paint()
      ..color = const Color(0xFFF5E6D3)
      ..style = PaintingStyle.fill;

    final hairPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    // ── Body (shirt) ─────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 36),
        width: 54,
        height: 36,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    // ── Neck ─────────────────────────────────────
    final neckPath = Path()
      ..moveTo(cx - 8, cy + 20)
      ..lineTo(cx + 8, cy + 20)
      ..lineTo(cx + 7, cy + 28)
      ..lineTo(cx - 7, cy + 28)
      ..close();
    canvas.drawPath(neckPath, skinPaint);

    // ── Head (face) ──────────────────────────────
    final headCenter = Offset(cx, cy + 4);
    const headRadius = 24.0;

    canvas.drawCircle(headCenter, headRadius, skinPaint);
    canvas.drawCircle(headCenter, headRadius, outlinePaint);

    // ── Eyes ─────────────────────────────────────
    final eyePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 8, cy + 2), width: 5, height: 6),
      eyePaint,
    );
    // Right eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 8, cy + 2), width: 5, height: 6),
      eyePaint,
    );

    // Eye highlights
    final highlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 6.5, cy + 1), 1.2, highlightPaint);
    canvas.drawCircle(Offset(cx + 9.5, cy + 1), 1.2, highlightPaint);

    // ── Eyebrows ──────────────────────────────────
    final browPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - 11, cy - 5),
      Offset(cx - 5, cy - 6.5),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + 5, cy - 6.5),
      Offset(cx + 11, cy - 5),
      browPaint,
    );

    // ── Nose ─────────────────────────────────────
    final nosePaint = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 8, height: 5),
      0,
      math.pi,
      false,
      nosePaint,
    );

    // ── Mouth (small smile) ───────────────────────
    final mouthPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(cx - 6, cy + 14)
      ..quadraticBezierTo(cx, cy + 18, cx + 6, cy + 14);
    canvas.drawPath(mouthPath, mouthPaint);

    // ── Hair (animated) ───────────────────────────
    canvas.save();
    // Pivot animation at crown of head
    canvas.translate(cx, cy - 18);
    canvas.rotate(hairSway);
    canvas.scale(hairBreath, hairBreath);
    canvas.translate(-cx, -(cy - 18));

    // Main hair blob (curly top)
    final hairPath = Path();
    hairPath.moveTo(cx - 20, cy - 5);
    // Left side sweep
    hairPath.cubicTo(
      cx - 28, cy - 18,
      cx - 24, cy - 36,
      cx - 10, cy - 34,
    );
    // Top center wave
    hairPath.cubicTo(
      cx - 4, cy - 40,
      cx + 4, cy - 40,
      cx + 10, cy - 34,
    );
    // Right side sweep
    hairPath.cubicTo(
      cx + 24, cy - 36,
      cx + 28, cy - 18,
      cx + 20, cy - 5,
    );
    // Close back along head
    hairPath.cubicTo(
      cx + 14, cy - 8,
      cx - 14, cy - 8,
      cx - 20, cy - 5,
    );
    hairPath.close();

    canvas.drawPath(hairPath, hairPaint);
    canvas.drawPath(hairPath, outlinePaint);

    // Small strand detail on right
    final strandPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final strand = Path()
      ..moveTo(cx + 16, cy - 28)
      ..cubicTo(cx + 20, cy - 24, cx + 22, cy - 16, cx + 19, cy - 8);
    canvas.drawPath(strand, strandPaint);

    canvas.restore();

    // ── Ears ─────────────────────────────────────
    canvas.drawCircle(Offset(cx - 24, cy + 4), 5.5, skinPaint);
    canvas.drawCircle(Offset(cx - 24, cy + 4), 5.5, outlinePaint);
    canvas.drawCircle(Offset(cx + 24, cy + 4), 5.5, skinPaint);
    canvas.drawCircle(Offset(cx + 24, cy + 4), 5.5, outlinePaint);
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.hairSway != hairSway || old.hairBreath != hairBreath;
}

// ─────────────────────────────────────────────
//  Premium Search Bar
// ─────────────────────────────────────────────
class _PremiumSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _PremiumSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFF161617),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF333335),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF7C7C81), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                hintText: 'Find anything',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF7C7C81),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, color: Color(0xFF7C7C81), size: 18),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Premium Tab Bar
// ─────────────────────────────────────────────
class _PremiumTabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _PremiumTabBar({required this.activeTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    const tabs = ['Social save', 'Self save'];
    return Row(
      children: [
        for (int i = 0; i < tabs.length; i++) ...[
          _TabChip(
            label: tabs[i],
            isActive: activeTab == i,
            onTap: () => onTabChanged(i),
          ),
          if (i < tabs.length - 1) const SizedBox(width: 24),
        ],
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Column(
          key: ValueKey(isActive),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : const Color(0xFF7C7C81),
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 2,
              width: isActive ? 52.0 : 0.0,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Profile Masonry Grid
// ─────────────────────────────────────────────
class _ProfileMasonryGrid extends StatelessWidget {
  final List<dynamic> items;
  final bool isOnline;

  const _ProfileMasonryGrid({required this.items, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1F),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2E2E2F),
                    width: 2.0,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bookmark_outline_rounded,
                    color: Color(0xFF7C7C81),
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No saved posts yet',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start saving things you like',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7C7C81),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final List<dynamic> left = [];
    final List<dynamic> right = [];
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final itemId = item is UserPost ? item.id : (item as PostModel).id;
      if (itemId.hashCode.isEven) {
        left.add(item);
      } else {
        right.add(item);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 378),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProfileMasonryColumn(items: left, isOnline: isOnline),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ProfileMasonryColumn(items: right, isOnline: isOnline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMasonryColumn extends StatelessWidget {
  final List<dynamic> items;
  final bool isOnline;

  const _ProfileMasonryColumn({
    required this.items,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _ProfilePostTile(
            key: ValueKey(items[i] is UserPost ? (items[i] as UserPost).id : (items[i] as PostModel).id),
            item: items[i],
            isOnline: isOnline,
          ),
          if (i < items.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ProfilePostTile extends StatefulWidget {
  final dynamic item;
  final bool isOnline;

  const _ProfilePostTile({
    super.key,
    required this.item,
    required this.isOnline,
  });

  @override
  State<_ProfilePostTile> createState() => _ProfilePostTileState();
}

class _ProfilePostTileState extends State<_ProfilePostTile> {
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

  double _getCardHeight(dynamic item) {
    if (item is UserPost) {
      final heights = [270.0, 210.0, 250.0, 180.0];
      final idx = item.id.hashCode.abs() % heights.length;
      return heights[idx];
    } else {
      return (item as PostModel).cardHeight;
    }
  }

  String _truncateTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'check out my new...';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length > 5) {
      return '${words.take(5).join(' ')}...';
    }
    return trimmed;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Widget _buildVaultPreviewWidget(UserPost post) {
    final String resolvedType = post.type ?? (
      post.imagePath != null ? 'image' : (
      post.videoPath != null ? 'video' : (
      post.url != null ? 'link' : (
      (post.checklistItems?.isNotEmpty ?? false) ? 'checklist' : (
      post.body.contains('```') ? 'code' : 'text'
    )))));

    if (resolvedType == 'image') {
      final path = post.imagePath;
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: path != null
            ? Image.file(
                File(path),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: const Color(0xFF2A2A2E),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 28),
                  ),
                ),
              )
            : Container(
                height: 120,
                color: const Color(0xFF2A2A2E),
                child: const Center(
                  child: Icon(Icons.image_outlined, color: Colors.white54, size: 28),
                ),
              ),
      );
    } else if (resolvedType == 'video') {
      final path = post.videoPath;
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: path != null
            ? SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RunningVideoPlayer(file: File(path)),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              )
            : Container(
                height: 120,
                color: const Color(0xFF2A2A2E),
                child: const Center(
                  child: Icon(Icons.video_file_outlined, color: Colors.white54, size: 28),
                ),
              ),
      );
    } else if (resolvedType == 'document') {
      final path = post.filePath;
      final name = path != null ? path.split('/').last.split('\\').last : 'document.pdf';
      final isPdf = name.toLowerCase().endsWith('.pdf');
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isPdf ? Colors.redAccent.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                color: isPdf ? Colors.redAccent : Colors.blue,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPdf ? 'PDF' : 'DOC',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7C7C81),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (resolvedType == 'contact') {
      final name = post.contactName ?? 'Unknown';
      final phone = post.contactPhone ?? 'No number';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8E8E93),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF555555),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (resolvedType == 'audio') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 14,
                child: CustomPaint(
                  painter: MiniWaveformPainter(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
          ],
        ),
      );
    } else if (resolvedType == 'link') {
      final url = post.url ?? '';
      final domain = Uri.tryParse(url)?.host ?? 'link';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.link_rounded, color: Colors.purpleAccent, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    url,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    domain,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7C7C81),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (resolvedType == 'checklist') {
      final itemsList = post.checklistItems ?? [];
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < math.min(itemsList.length, 5); i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itemsList[i],
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (resolvedType == 'code') {
      return Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          post.body.trim().isNotEmpty ? post.body.trim() : 'hello world',
          style: const TextStyle(
            fontFamily: 'Cascadia Code',
            color: Color(0xFFB71C1C),
            fontSize: 11,
          ),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2E),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.topLeft,
        child: RichTextController.buildRichText(
          post.body,
          post.charStyles,
          defaultStyle: GoogleFonts.inter(
            color: const Color(0xFFAEAEB2),
            fontSize: 11,
            fontWeight: FontWeight.w300,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showShimmer = !widget.isOnline || _showShimmer;
    final cardHeight = _getCardHeight(widget.item);

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
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }

    void showPreviewDialog() {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          Widget media;
          if (widget.item is UserPost) {
            final post = widget.item as UserPost;
            if (post.videoPath != null) {
              media = RunningVideoPlayer(file: File(post.videoPath!));
            } else if (post.imagePath != null) {
              media = Image.file(File(post.imagePath!), fit: BoxFit.contain);
            } else {
              media = Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF1C1C1E),
                child: Text(post.body, style: const TextStyle(color: Colors.white, fontSize: 16)),
              );
            }
          } else {
            final post = widget.item as PostModel;
            if (post.mediaType == PostMediaType.video) {
              media = RunningVideoPlayer(assetPath: post.mediaAssetPath);
            } else {
              media = Image.asset(post.mediaAssetPath, fit: BoxFit.contain);
            }
          }
          
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.95),
                      child: media,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (showShimmer) {
      return ShimmerContainer(
        key: const ValueKey('shimmer'),
        height: cardHeight,
        baseColor: const Color(0xFF2A2A2E),
      );
    }

    final itemId = widget.item is UserPost
        ? (widget.item as UserPost).id
        : (widget.item as PostModel).id;

    if (widget.item is UserPost) {
      final post = widget.item as UserPost;
      final previewWidget = _buildVaultPreviewWidget(post);
      final truncatedTitle = _truncateTitle(post.title);
      final String formattedDate = _formatDate(post.createdAt);

      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: GestureDetector(
                  onTap: showPreviewDialog,
                  child: previewWidget,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  truncatedTitle,
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
              const SizedBox(height: 4),
              if (post.body.isNotEmpty && post.type != 'code' && post.type != 'checklist')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFC7C7CC),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 8),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    formattedDate,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFC7C7CC),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        PostStore.instance.likedPostIdsNotifier,
        PostStore.instance.savedSocialPostIdsNotifier,
      ]),
      builder: (context, _) {
        final isLiked = PostStore.instance.likedPostIds.contains(itemId);
        final isSaved = PostStore.instance.savedSocialPostIds.contains(itemId);

        final likes = isLiked ? '1' : '0';
        final bookmarks = _format(isSaved
            ? (widget.item as PostModel).savesCount + 1
            : (widget.item as PostModel).savesCount);
        Widget mediaWidget;

        final post = widget.item as PostModel;
        
        Widget childWidget;
        if (post.mediaType == PostMediaType.video) {
          childWidget = RunningVideoPlayer(
            assetPath: post.mediaAssetPath,
          );
        } else {
          childWidget = Image.asset(
            post.mediaAssetPath,
            fit: BoxFit.cover,
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

        final titleText = post.title ?? '';
        final userText = post.username ?? 'Unknown';
        final avatarAsset = post.avatarAssetPath;
        final initial = userText.isNotEmpty ? userText[0].toUpperCase() : '?';
        final color = post.accentColor ?? const Color(0xFF7B61FF);

        return FeedCard(
          imageWidget: mediaWidget,
          title: titleText,
          username: userText,
          avatarAssetPath: avatarAsset,
          avatarInitial: initial,
          avatarColor: color,
          likes: likes,
          bookmarks: bookmarks,
          isLiked: isLiked,
          isSaved: isSaved,
          onLikeTap: () => PostStore.instance.toggleLikedPost(itemId),
          onSaveTap: () => PostStore.instance.toggleSavedSocialPost(itemId),
          onCardTap: onTap,
          onImageTap: showPreviewDialog,
        );
      },
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
                painter: ArrowPainter2(),
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

class ArrowPainter2 extends CustomPainter {
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

// ─────────────────────────────────────────────
//  FAB Components
// ─────────────────────────────────────────────
class _FloatingFab extends StatefulWidget {
  final bool expanded;

  const _FloatingFab({required this.expanded});

  @override
  State<_FloatingFab> createState() => _FloatingFabState();
}

class _FloatingFabState extends State<_FloatingFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _idleController;
  late Animation<double> _idleFloat;

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _idleFloat = Tween<double>(begin: 0, end: -3.5).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idleFloat,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _idleFloat.value),
        child: child,
      ),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  FAB Action row: label pill + white circle icon
// ─────────────────────────────────────────────
class _FabAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FabAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_FabAction> createState() => _FabActionState();
}

class _FabActionState extends State<_FabAction> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3C),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.black, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniWaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8E8E93)
      ..style = PaintingStyle.fill;
    
    const int barCount = 12;
    const double spacing = 3.0;
    final double totalSpacing = spacing * (barCount - 1);
    final double barWidth = (size.width - totalSpacing) / barCount;
    
    final heights = [0.4, 0.6, 0.9, 0.5, 0.8, 0.3, 0.7, 0.5, 0.8, 0.4, 0.6, 0.3];
    
    for (int i = 0; i < barCount; i++) {
      final double x = i * (barWidth + spacing);
      final double h = size.height * heights[i % heights.length];
      final double y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
