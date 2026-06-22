import 'dart:math' as math;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/parsed_text_with_code_blocks.dart';
import '../../utils/translation_manager.dart';
import '../../models/post_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/shimmer_container.dart';
import '../../widgets/feed_card.dart';
import '../../widgets/running_video_player.dart';
import '../../widgets/animated_avatar.dart';
import '../../widgets/dice_avatar.dart';
import '../../utils/user_store.dart';
import '../../avatar_setup_screen.dart';
import '../../utils/share_helper.dart';
import 'settings_screen.dart';
import '../notifications/notification_screen.dart';
import '../../utils/post_store.dart';
import '../post_detail/post_detail_screen.dart';
import '../../utils/rich_text_controller.dart';
import '../post/write_post_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'locked_folder/locked_folder_screen.dart';
import 'locked_folder/pin_entry_screen.dart';
import 'locked_folder/pin_setup_screen.dart';


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
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;
  bool _isOnline = true;
  Timer? _connectivityTimer;
  
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelection(String id) {
    if (!_isSelectionMode) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _onLongPress(String id) {
    if (!_isSelectionMode) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isSelectionMode = true;
        _selectedIds.add(id);
      });
    }
  }

  Future<bool?> _showDeleteConfirmation(BuildContext context, int count) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF3B30),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  count > 1 ? 'Delete $count Items?' : 'Delete Item?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  count > 1
                      ? 'Are you sure you want to permanently delete these items? This action cannot be undone.'
                      : 'Are you sure you want to permanently delete this item? This action cannot be undone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFAEAEB2),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  final TextEditingController _searchController = TextEditingController();
  String _profileSearchQuery = "";
  String _activeCategoryChip = "All";
  String _activeSocialCategoryChip = "POST";

  bool get _isMyProfile {
    final currentUser = UserStore.instance.currentUser;
    return widget.username == null ||
        widget.username == 'gangster_vagas' ||
        (currentUser != null && widget.username == currentUser.userId);
  }

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
    final categories = ['All', 'Documents', 'Media', 'Contacts', 'Audio', 'Ideas'];
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
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.0,
                    ),
                  ),
                ),
                child: Text(
                  cat,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFF7C7C81),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSocialCategoryChips() {
    final categories = ['POST', 'FEED SAVE'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _activeSocialCategoryChip == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeSocialCategoryChip = cat;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2.0,
                  ),
                ),
              ),
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : const Color(0xFF7C7C81),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Mock saves are now reactively queried from the central PostStore.instance

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (mounted) setState(() => _scrollOffset = _scrollController.offset);
    });

    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkConnectivity();
    });

    PostStore.instance.postsNotifier.addListener(_onPostsChanged);
    PostStore.instance.likedPostIdsNotifier.addListener(_onPostsChanged);
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    PostStore.instance.postsNotifier.removeListener(_onPostsChanged);
    PostStore.instance.likedPostIdsNotifier.removeListener(_onPostsChanged);
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

  Future<void> _openLockedFolder() async {
    const storage = FlutterSecureStorage();
    final savedPin = await storage.read(key: 'memoria_locked_folder_pin');
    
    if (!mounted) return;
    
    if (savedPin == null) {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (success == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LockedFolderScreen()),
        );
      }
    } else {
      final success = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PinEntryScreen()),
      );
      if (success == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LockedFolderScreen()),
        );
      }
    }
  }

  String _getJoinedDate() {
    if (!_isMyProfile) return 'Joined 15 Jun 2024';
    final createdAt = UserStore.instance.currentUser?.createdAt ?? 0;
    if (createdAt == 0) return 'Joined 1 Jan 2024';
    final date = DateTime.fromMillisecondsSinceEpoch(createdAt);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
    return 'Joined ${date.day} $monthStr ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = UserStore.instance.currentUser;
    final currentUserId = currentUser?.userId ?? 'gangster_vagas';
    
    int likesCount = 0;
    int postsCount = 0;

    if (_isMyProfile) {
      likesCount = PostStore.instance.likedPostIds.length;
      postsCount = PostStore.instance.posts
          .where((p) => p.username == currentUserId)
          .length;
    } else {
      likesCount = 0;
      postsCount = PostStore.instance.posts
          .where((p) => p.username == widget.username)
          .length;
      postsCount += PostStore.predefinedPosts
          .where((p) => p.username == widget.username)
          .length;
    }

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
            backgroundColor: Colors.transparent,
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
                            if (_isSelectionMode)
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedIds.clear();
                                  });
                                },
                                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              )
                            else
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
                              _isSelectionMode ? '${_selectedIds.length} Selected' : 'Profile',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (_isSelectionMode) ...[
                              IconButton(
                                onPressed: _selectedIds.isEmpty ? null : () {
                                  PostStore.instance.lockUserPosts(_selectedIds);
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedIds.clear();
                                  });
                                },
                                icon: Icon(Icons.lock, color: _selectedIds.isEmpty ? Colors.grey : Colors.white, size: 24),
                                tooltip: 'Move to Locked Folder',
                              ),
                              IconButton(
                                onPressed: _selectedIds.isEmpty ? null : () async {
                                  final confirmed = await _showDeleteConfirmation(context, _selectedIds.length);
                                  if (confirmed == true) {
                                    PostStore.instance.removeUserPosts(_selectedIds);
                                    setState(() {
                                      _isSelectionMode = false;
                                      _selectedIds.clear();
                                    });
                                  }
                                },
                                icon: Icon(Icons.delete, color: _selectedIds.isEmpty ? Colors.grey : Colors.redAccent, size: 24),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ] else ...[
                              IconButton(
                                onPressed: _openLockedFolder,
                                icon: const Icon(Icons.lock_outline, color: Colors.white, size: 24),
                                tooltip: 'Locked Folder',
                              ),
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
                              const SizedBox(height: 8),

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
                                        child: _isMyProfile
                                            ? GestureDetector(
                                                onTap: () async {
                                                  await Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => const AvatarSetupScreen(isFromProfile: true),
                                                    ),
                                                  );
                                                  if (mounted) setState(() {});
                                                },
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.click,
                                                  child: Tooltip(
                                                    message: 'Customize Avatar',
                                                    child: const DiceAvatar(
                                                      radius: 65,
                                                      backgroundColor: Colors.transparent,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : (widget.avatarAssetPath != null || widget.avatarInitial != null)
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
                                                : const AnimatedAvatar(size: 130),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isMyProfile
                                                ? (UserStore.instance.currentUser?.name ?? 'Gangster Vagas')
                                                : (widget.username ?? 'gangster_vagas'),
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '@${_isMyProfile ? (UserStore.instance.currentUser?.userId ?? 'gangster_vagas') : (widget.username ?? 'gangster_vagas')}',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF7C7C81),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getJoinedDate(),
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
                                                    '$likesCount',
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
                                                    '$postsCount',
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

                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: _PremiumTabBar(
                                  activeTab: _activeTab,
                                  onTabChanged: (i) => setState(() => _activeTab = i),
                                ),
                              ),

                              if (_activeTab == 0) ...[
                                const SizedBox(height: 16),
                                _buildCategoryChips(),
                              ] else if (_activeTab == 1 && _isMyProfile) ...[
                                const SizedBox(height: 16),
                                _buildSocialCategoryChips(),
                              ],

                              const SizedBox(height: 18),

                              _buildProfileGrid(),

                              const SizedBox(height: 100),
                            ],
                          ),
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
                    isAddMenuOpen: false,
                    onAddTap: () {},
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
    final bool isMyProfile = _isMyProfile;
    final query = _profileSearchQuery.toLowerCase().trim();

    if (_activeTab == 1) {
      if (isMyProfile) {
        if (_activeSocialCategoryChip == 'POST') {
          return ValueListenableBuilder<List<UserPost>>(
            valueListenable: PostStore.instance.postsNotifier,
            builder: (context, postsList, _) {
              var userPublicPosts = postsList.where((p) => !p.savedInProfile).toList();
              
              if (query.isNotEmpty) {
                userPublicPosts = userPublicPosts.where((item) {
                  return item.title.toLowerCase().contains(query) ||
                         item.body.toLowerCase().contains(query) ||
                         (item.url?.toLowerCase().contains(query) ?? false);
                }).toList();
              }
              
              if (userPublicPosts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No public posts found.',
                      style: GoogleFonts.inter(color: const Color(0xFF7C7C81), fontSize: 14),
                    ),
                  ),
                );
              }

              return ProfileMasonryGrid(
                items: userPublicPosts, 
                isOnline: _isOnline,
                isSelectionMode: _isSelectionMode,
                selectedIds: _selectedIds,
                onSelectToggle: _toggleSelection,
                onLongPress: _onLongPress,
              );
            },
          );
        } else {
          // FEED SAVE
          return ValueListenableBuilder<Set<String>>(
            valueListenable: PostStore.instance.savedSocialPostIdsNotifier,
            builder: (context, savedSocialIds, _) {
              final savedPredefined = PostStore.predefinedPosts
                  .where((p) => savedSocialIds.contains(p.id))
                  .toList();
              var savedSocial = [...savedPredefined];

              if (query.isNotEmpty) {
                savedSocial = savedSocial.where((item) {
                  return (item.title?.toLowerCase().contains(query) ?? false) ||
                         (item.description?.toLowerCase().contains(query) ?? false) ||
                         (item.username?.toLowerCase().contains(query) ?? false) ||
                         (item.url?.toLowerCase().contains(query) ?? false);
                }).toList();
              }

              if (savedSocial.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No saved feed items.',
                      style: GoogleFonts.inter(color: const Color(0xFF7C7C81), fontSize: 14),
                    ),
                  ),
                );
              }

              return ProfileMasonryGrid(
                items: savedSocial, 
                isOnline: _isOnline,
                isSelectionMode: _isSelectionMode,
                selectedIds: _selectedIds,
                onSelectToggle: _toggleSelection,
                onLongPress: _onLongPress,
              );
            },
          );
        }
      } else {
        var friendPosts = PostStore.predefinedPosts.where((p) => p.username == widget.username).toList();
        if (query.isNotEmpty) {
          friendPosts = friendPosts.where((p) {
            return (p.title?.toLowerCase().contains(query) ?? false) ||
                   (p.description?.toLowerCase().contains(query) ?? false) ||
                   (p.url?.toLowerCase().contains(query) ?? false);
          }).toList();
        }
        return ProfileMasonryGrid(
          items: friendPosts, 
          isOnline: _isOnline,
          isSelectionMode: _isSelectionMode,
          selectedIds: _selectedIds,
          onSelectToggle: _toggleSelection,
          onLongPress: _onLongPress,
        );
      }
    } else {
      if (isMyProfile) {
        return ValueListenableBuilder<List<UserPost>>(
          valueListenable: PostStore.instance.postsNotifier,
          builder: (context, postsList, _) {
            var savedUserPosts = postsList.where((p) => !p.isLocked && p.savedInProfile).toList();

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
                ProfileMasonryGrid(
                  items: savedUserPosts, 
                  isOnline: _isOnline,
                  isSelectionMode: _isSelectionMode,
                  selectedIds: _selectedIds,
                  onSelectToggle: _toggleSelection,
                  onLongPress: _onLongPress,
                ),
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
        return ProfileMasonryGrid(
          items: friendPosts, 
          isOnline: _isOnline,
          isSelectionMode: _isSelectionMode,
          selectedIds: _selectedIds,
          onSelectToggle: _toggleSelection,
          onLongPress: _onLongPress,
        );
      }
    }
  }
}

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
          color: const Color(0xFFFAF096),
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

class _PremiumTabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _PremiumTabBar({
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = ['Self save', 'Social save'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (int i = 0; i < tabs.length; i++) ...[
            _TabButton(
              label: tabs[i],
              isActive: activeTab == i,
              onTap: () => onTabChanged(i),
            ),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final IconData? icon;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white : const Color(0xFF333335),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.black : const Color(0xFF7C7C81),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? Colors.black : const Color(0xFF7C7C81),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileMasonryGrid extends StatelessWidget {
  final List<dynamic> items;
  final bool isOnline;
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function(String) onSelectToggle;
  final Function(String) onLongPress;

  const ProfileMasonryGrid({
    required this.items,
    required this.isOnline,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    required this.onSelectToggle,
    required this.onLongPress,
  });

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
          constraints: const BoxConstraints(maxWidth: 500),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ProfileMasonryColumn(
                  items: left, 
                  isOnline: isOnline,
                  isSelectionMode: isSelectionMode,
                  selectedIds: selectedIds,
                  onSelectToggle: onSelectToggle,
                  onLongPress: onLongPress,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ProfileMasonryColumn(
                  items: right, 
                  isOnline: isOnline,
                  isSelectionMode: isSelectionMode,
                  selectedIds: selectedIds,
                  onSelectToggle: onSelectToggle,
                  onLongPress: onLongPress,
                ),
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
  final bool isSelectionMode;
  final Set<String> selectedIds;
  final Function(String) onSelectToggle;
  final Function(String) onLongPress;

  const _ProfileMasonryColumn({
    required this.items,
    required this.isOnline,
    required this.isSelectionMode,
    required this.selectedIds,
    required this.onSelectToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          ProfilePostTile(
            key: ValueKey(items[i] is UserPost ? (items[i] as UserPost).id : (items[i] as PostModel).id),
            item: items[i],
            isOnline: isOnline,
            isSelectionMode: isSelectionMode,
            isSelected: selectedIds.contains(items[i] is UserPost ? (items[i] as UserPost).id : (items[i] as PostModel).id),
            onSelectToggle: () => onSelectToggle(items[i] is UserPost ? (items[i] as UserPost).id : (items[i] as PostModel).id),
            onLongPress: () => onLongPress(items[i] is UserPost ? (items[i] as UserPost).id : (items[i] as PostModel).id),
          ),
          if (i < items.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class ProfilePostTile extends StatefulWidget {
  final dynamic item;
  final bool isOnline;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelectToggle;
  final VoidCallback onLongPress;

  const ProfilePostTile({
    super.key,
    required this.item,
    required this.isOnline,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onSelectToggle,
    required this.onLongPress,
  });

  @override
  State<ProfilePostTile> createState() => _ProfilePostTileState();
}

class _ProfilePostTileState extends State<ProfilePostTile> {
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
      (post.checklistItems?.isNotEmpty ?? false) ? 'checklist' : 'text'
    ))));

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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPdf ? 'PDF Document' : 'Text Document',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFAEAEB2),
                      fontSize: 10,
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
      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
      final gradients = [
        [const Color(0xFF7B61FF), const Color(0xFF4A90E2)],
        [const Color(0xFFE24A6A), const Color(0xFFFF8A00)],
        [const Color(0xFF2ECC71), const Color(0xFF1ABC9C)],
      ];
      final grad = gradients[name.codeUnitAt(0) % gradients.length];

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    phone,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFAEAEB2),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 16,
                child: CustomPaint(
                  painter: MiniWaveformPainter(activeColor: Colors.white, inactiveColor: Colors.white24),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
          ],
        ),
      );
    } else if (resolvedType == 'link') {
      final url = post.url ?? '';
      final domain = Uri.tryParse(url)?.host ?? 'link';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
              ),
              child: const Icon(Icons.link_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    url,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    domain,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFAEAEB2),
                      fontSize: 10,
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
        padding: const EdgeInsets.all(14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < math.min(itemsList.length, 5); i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
                      ),
                      child: const Center(
                        child: Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        itemsList[i],
                        style: GoogleFonts.inter(
                          color: const Color(0xFFD1D1D6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
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
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(bottom: BorderSide(color: const Color(0xFFFAF096), width: 1.0)),
              ),
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: const Color(0xFFFAF096), width: 1), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: const Color(0xFFFAF096), width: 1), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.transparent, border: Border.all(color: const Color(0xFFFAF096), width: 1), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Text(
                    'Code Snippet',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ParsedTextWithCodeBlocks(
                text: post.body,
                charStyles: post.charStyles,
                isPreviewMode: true,
                defaultStyle: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
                maxLinesForText: 5,
                overflowForText: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
        ),
        alignment: Alignment.topLeft,
        child: ParsedTextWithCodeBlocks(
          text: post.body,
          charStyles: post.charStyles,
          isPreviewMode: true,
          defaultStyle: GoogleFonts.inter(
            color: const Color(0xFFD1D1D6),
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          maxLinesForText: 6,
          overflowForText: TextOverflow.ellipsis,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showShimmer = !widget.isOnline || _showShimmer;
    final cardHeight = _getCardHeight(widget.item);

    void onTap() {
      if (widget.isSelectionMode) {
        widget.onSelectToggle();
        return;
      }

      if (widget.item is UserPost && (widget.item as UserPost).savedInProfile) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, _, _) => WritePostScreen(
              isSaveItem: true,
              editingPost: widget.item as UserPost,
            ),
            transitionsBuilder: (context, animation, _, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
        return;
      }

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

    if (widget.item is UserPost && (widget.item as UserPost).savedInProfile) {
      final post = widget.item as UserPost;
      final previewWidget = _buildVaultPreviewWidget(post);
      final truncatedTitle = _truncateTitle(post.title);
      final String formattedDate = _formatDate(post.createdAt);

      return GestureDetector(
        onTap: onTap,
        onLongPress: widget.onLongPress,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3A3A3B),
                borderRadius: BorderRadius.circular(10),
                border: widget.isSelected ? Border.all(color: const Color(0xFFFAF096), width: 2) : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                child: GestureDetector(
                  onTap: onTap,
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
            if (widget.isSelected)
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
                    color: Colors.transparent,
                  ),
                ),
              ),
          ],
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
        final bookmarks = widget.item is UserPost
            ? (isSaved ? '1' : '0')
            : _format(isSaved
                ? (widget.item as PostModel).savesCount + 1
                : (widget.item as PostModel).savesCount);
        Widget mediaWidget;

        if (widget.item is UserPost) {
          final post = widget.item as UserPost;
          if (post.videoPath != null) {
            mediaWidget = RunningVideoPlayer(
              file: File(post.videoPath!),
            );
          } else if (post.imagePath != null) {
            mediaWidget = Image.file(
              File(post.imagePath!),
              fit: BoxFit.cover,
              width: double.infinity,
            );
          } else {
            mediaWidget = _buildVaultPreviewWidget(post);
          }
        } else {
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
        }

        final titleText = widget.item is UserPost ? (widget.item as UserPost).title : (widget.item as PostModel).title ?? '';
        final userText = widget.item is UserPost ? (widget.item.username ?? 'gangster_vagas') : (widget.item as PostModel).username ?? 'Unknown';
        final avatarAsset = widget.item is UserPost ? null : (widget.item as PostModel).avatarAssetPath;
        final initial = userText.isNotEmpty ? userText[0].toUpperCase() : '?';
        final color = widget.item is UserPost ? const Color(0xFF6B9BF7) : (widget.item as PostModel).accentColor ?? const Color(0xFF7B61FF);
        final sharesText = widget.item is UserPost ? '0' : _format((widget.item as PostModel).sharesCount);

        return FeedCard(
          imageWidget: mediaWidget,
          title: titleText,
          username: userText,
          avatarAssetPath: avatarAsset,
          avatarInitial: initial,
          avatarColor: color,
          likes: likes,
          bookmarks: bookmarks,
          shares: sharesText,
          isLiked: isLiked,
          isSaved: isSaved,
          isSelected: widget.isSelected,
          onLikeTap: () => PostStore.instance.toggleLikedPost(itemId),
          onSaveTap: () => PostStore.instance.toggleSavedSocialPost(itemId),
          onShareTap: () async {
            if (widget.item is UserPost) {
              final post = widget.item as UserPost;
              await ShareHelper.sharePost(
                title: post.title,
                description: post.body,
                url: post.url,
                localImagePath: post.imagePath,
                localVideoPath: post.videoPath,
                author: 'You',
              );
            } else {
              final post = widget.item as PostModel;
              await ShareHelper.sharePost(
                title: post.title ?? '',
                description: post.description,
                url: post.url,
                assetPath: post.mediaAssetPath,
                author: post.username ?? 'Unknown',
              );
            }
          },
          onCardTap: onTap,
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



class MiniWaveformPainter extends CustomPainter {
  final Color? activeColor;
  final Color? inactiveColor;

  MiniWaveformPainter({this.activeColor, this.inactiveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = inactiveColor ?? const Color(0xFF8E8E93)
      ..style = PaintingStyle.fill;
    
    final activePaint = Paint()
      ..color = activeColor ?? const Color(0xFF8E8E93)
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
        i < barCount / 3 ? activePaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
