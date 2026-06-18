import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/post_model.dart';
import '../../screens/notifications/notification_screen.dart';
import '../../screens/post_detail/post_detail_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/profile/settings_screen.dart';
import '../../screens/post/write_post_screen.dart';
import '../../login_screen.dart';
import '../../utils/post_store.dart';
import '../../utils/share_helper.dart';
import '../../utils/translation_manager.dart';
import '../../widgets/app_bottom_navigation.dart';
import '../../widgets/feed_header.dart';
import '../../widgets/shimmer_container.dart';
import '../../widgets/feed_card.dart';
import '../../widgets/running_video_player.dart';
import '../../widgets/premium_drawer.dart';
import '../../utils/rich_text_controller.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;
  bool _isOnline = true;
  Timer? _connectivityTimer;

  List<dynamic> _shuffledPredefinedPosts = [];
  bool _isRefreshing = false;
  final _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isAddMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _shuffledPredefinedPosts = List.from(PostStore.predefinedPosts);
    _checkConnectivity();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkConnectivity();
    });
    // Listen for new posts to rebuild
    PostStore.instance.postsNotifier.addListener(_onPostsChanged);
    
    // Load local cached posts and then trigger online sync
    PostStore.instance.loadFromLocal().then((_) {
      PostStore.instance.syncOnlinePosts();
    });
    
    // Initialize share intent listener
    _initShareIntentListener();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _searchController.dispose();
    PostStore.instance.postsNotifier.removeListener(_onPostsChanged);
    super.dispose();
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleBackPress() async {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
      return;
    }

    if (_isAddMenuOpen) {
      setState(() {
        _isAddMenuOpen = false;
      });
      return;
    }

    if (_currentTab != 0) {
      setState(() {
        _currentTab = 0;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final skipConfirm = prefs.getBool('skip_exit_confirmation') ?? false;
    
    if (skipConfirm) {
      SystemNavigator.pop();
      return;
    }

    _showExitConfirmationDialog();
  }

  void _showExitConfirmationDialog() {
    bool dontShowAgain = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: const Color(0xFF161618),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Minimalist Power Icon (instead of generic red circle)
                      Center(
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.07),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            color: Colors.white.withValues(alpha: 0.75),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text(
                        'Exit Memoria?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Are you sure you want to close the app? You can save your session automatically.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Premium Custom Radio-style Checkbox
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            dontShowAgain = !dontShowAgain;
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            color: Colors.transparent,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: dontShowAgain ? const Color(0xFFFAF096) : Colors.transparent,
                                    border: Border.all(
                                      color: dontShowAgain ? const Color(0xFFFAF096) : Colors.white.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: dontShowAgain
                                      ? const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.black,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Do not ask again',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.65),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Action Buttons
                      Row(
                        children: [
                          // Stay Button (Primary / Filled)
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'Stay',
                                style: GoogleFonts.inter(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Exit Button (Secondary / Outlined)
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              onPressed: () async {
                                if (dontShowAgain) {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('skip_exit_confirmation', true);
                                }
                                SystemNavigator.pop();
                              },
                              child: Text(
                                'Exit',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFFF453A).withValues(alpha: 0.85),
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
          ),
        );
      },
    );
  }

  static const _shareChannel = MethodChannel('com.example.memoria_flutter/share_intent');

  Future<void> _initShareIntentListener() async {
    // 1. Listen for new intents when the app is already open (warm-start)
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedIntent') {
        final data = Map<String, dynamic>.from(call.arguments);
        _handleSharedIntent(data);
      }
    });

    // 2. Query the initial intent if the app was cold-started (cold-start)
    try {
      final initialData = await _shareChannel.invokeMethod('getSharedIntent');
      if (initialData != null) {
        final data = Map<String, dynamic>.from(initialData);
        _handleSharedIntent(data);
      }
    } catch (e) {
      debugPrint("Error fetching initial shared intent: $e");
    }
  }

  void _handleSharedIntent(Map<String, dynamic> data) {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WritePostScreen(isSaveItem: true, sharedData: data),
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
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOnline != online) {
        setState(() => _isOnline = online);
      }
    } catch (_) {
      if (mounted && _isOnline != false) {
        setState(() => _isOnline = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userPublicPosts = PostStore.instance.posts.where((p) => !p.savedInProfile).toList();
    final List<dynamic> allItems = [
      ...userPublicPosts,
      ..._shuffledPredefinedPosts,
    ];

    final filteredItems = allItems.where((item) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (item is UserPost) {
        return item.title.toLowerCase().contains(q) ||
            item.body.toLowerCase().contains(q) ||
            (item.url?.toLowerCase().contains(q) ?? false);
      } else if (item is PostModel) {
        return (item.title?.toLowerCase().contains(q) ?? false) ||
            (item.description?.toLowerCase().contains(q) ?? false) ||
            (item.url?.toLowerCase().contains(q) ?? false);
      }
      return false;
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        _handleBackPress();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFF272729),
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      child: Scaffold(
        key: _scaffoldKey,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        backgroundColor: const Color(0xFF121212),
        drawer: PremiumDrawer(
          currentTab: _currentTab,
          onTabSelected: (index) {
            setState(() {
              _currentTab = index;
            });
          },
          onSaveItemTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const WritePostScreen(isSaveItem: true),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final slideAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 0.08),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                  final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeIn));
                  return FadeTransition(opacity: fadeAnimation, child: SlideTransition(position: slideAnimation, child: child));
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          onHelpTap: () async {
            final uri = Uri.parse('https://memoria-website-sigma.vercel.app/support');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          onSettingsTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (ctx, anim, x) => const SettingsScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: child,
                  ),
                ),
                transitionDuration: const Duration(milliseconds: 450),
              ),
            );
          },
          onLogoutTap: () async {
            final navigator = Navigator.of(context);
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', false);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  TranslationManager.t('loggingOut'),
                  style: GoogleFonts.inter(color: Colors.white),
                ),
                backgroundColor: const Color(0xFFEB4335),
                duration: const Duration(milliseconds: 800),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            Future.delayed(const Duration(milliseconds: 800), () {
              navigator.pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeIn),
                    );
                    return FadeTransition(opacity: fadeAnimation, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 500),
                ),
                (route) => false,
              );
            });
          },
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _currentTab,
              children: [
                Column(
                  children: [
                    FeedHeader(
                      onMenuTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      onSearchChanged: (query) {
                        setState(() {
                          _searchQuery = query;
                        });
                      },
                      onNotificationTap: () {
                        setState(() {
                          _currentTab = 2;
                        });
                      },
                    ),
                    Expanded(
                      child: _isRefreshing
                          ? _buildShimmerGrid()
                          : RefreshIndicator(
                              onRefresh: () async {
                                _refreshFeed();
                                // Wait for sync to finish to dismiss indicator
                                await Future.delayed(const Duration(milliseconds: 500));
                              },
                              color: const Color(0xFF7B61FF),
                              backgroundColor: const Color(0xFF1C1C1E),
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                padding: const EdgeInsets.all(16),
                              child: ValueListenableBuilder<Set<String>>(
                                valueListenable: PostStore.instance.savedSocialPostIdsNotifier,
                                builder: (context, savedSocialIds, _) {
                                  return filteredItems.isEmpty && _searchQuery.trim().isNotEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 80),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.search_off, color: Color(0xFF7C7C81), size: 48),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'No items match your search',
                                                  style: GoogleFonts.inter(
                                                    color: const Color(0xFF7C7C81),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Container(
                                            constraints: const BoxConstraints(maxWidth: 500),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Left Column
                                                Expanded(
                                                  child: Column(
                                                    children: _buildStaggeredList(filteredItems, left: true),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                // Right Column
                                                Expanded(
                                                  child: Column(
                                                    children: _buildStaggeredList(filteredItems, left: false),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                },
                              ),
                              ),
                            ),
                    ),
                  ],
                ),
                _buildSearchPage(),
                NotificationScreen(
                  showBottomNav: false,
                  showBackButton: true,
                  onBackTap: () {
                    setState(() {
                      _currentTab = 0;
                    });
                  },
                ),
                ProfileScreen(
                  showBottomNav: false,
                  showBackButton: true,
                  onBackTap: () {
                    setState(() {
                      _currentTab = 0;
                    });
                  },
                ),
              ],
            ),
            // Background Dimming Scrim
            IgnorePointer(
              ignoring: !_isAddMenuOpen,
              child: AnimatedOpacity(
                opacity: _isAddMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAddMenuOpen = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            // Premium Horizontal Fanned-Out Add Menu Popup
            Positioned(
              bottom: 60 + MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_isAddMenuOpen,
                child: Center(
                  child: SizedBox(
                    width: 280,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        // Left Option: Write a Post
                        AnimatedAlign(
                          duration: _isAddMenuOpen ? const Duration(milliseconds: 350) : const Duration(milliseconds: 250),
                          curve: _isAddMenuOpen ? Curves.easeOutBack : Curves.easeInOutCubic,
                          alignment: _isAddMenuOpen ? const Alignment(-0.65, -0.6) : Alignment.bottomCenter,
                          child: AnimatedScale(
                            scale: _isAddMenuOpen ? 1.0 : 0.0,
                            duration: _isAddMenuOpen ? const Duration(milliseconds: 300) : const Duration(milliseconds: 200),
                            curve: _isAddMenuOpen ? Curves.easeOutBack : Curves.easeIn,
                            child: _buildCircularAddOption(
                              icon: Icons.edit_outlined,
                              label: 'Write Post',
                              onTap: () => _navigateToWritePost(isSaveItem: false),
                              isOpen: _isAddMenuOpen,
                              isLeft: true,
                            ),
                          ),
                        ),
                        // Right Option: Save an Item
                        AnimatedAlign(
                          duration: _isAddMenuOpen ? const Duration(milliseconds: 350) : const Duration(milliseconds: 250),
                          curve: _isAddMenuOpen ? Curves.easeOutBack : Curves.easeInOutCubic,
                          alignment: _isAddMenuOpen ? const Alignment(0.65, -0.6) : Alignment.bottomCenter,
                          child: AnimatedScale(
                            scale: _isAddMenuOpen ? 1.0 : 0.0,
                            duration: _isAddMenuOpen ? const Duration(milliseconds: 300) : const Duration(milliseconds: 200),
                            curve: _isAddMenuOpen ? Curves.easeOutBack : Curves.easeIn,
                            child: _buildCircularAddOption(
                              icon: Icons.bookmark_border_rounded,
                              label: 'Save Item',
                              onTap: () => _navigateToWritePost(isSaveItem: true),
                              isOpen: _isAddMenuOpen,
                              isLeft: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentTab,
          isAddMenuOpen: _isAddMenuOpen,
          onTabChanged: (index) {
            if (_isAddMenuOpen) {
              setState(() => _isAddMenuOpen = false);
            }
            if (index == 0 && _currentTab == 0) {
              _refreshFeed();
            }
            setState(() => _currentTab = index);
          },
          onAddTap: () {
            setState(() {
              _isAddMenuOpen = !_isAddMenuOpen;
            });
          },
        ),
      ),
    ),
  );
}

  Widget _buildCircularAddOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isOpen,
    required bool isLeft,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedRotation(
          turns: isOpen ? 0.0 : (isLeft ? -0.25 : 0.25),
          duration: isOpen ? const Duration(milliseconds: 350) : const Duration(milliseconds: 200),
          curve: isOpen ? Curves.easeOutBack : Curves.easeInOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              highlightColor: const Color(0xFFFAF096).withValues(alpha: 0.2),
              splashColor: const Color(0xFFFAF096).withValues(alpha: 0.35),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF272729),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            shadows: [
              const Shadow(
                color: Colors.black,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToWritePost({required bool isSaveItem}) {
    setState(() {
      _isAddMenuOpen = false;
    });

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            WritePostScreen(isSaveItem: isSaveItem),
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
  }

  List<Widget> _buildStaggeredList(List<dynamic> allItems, {required bool left}) {
    final List<Widget> columnWidgets = [];
    
    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      final itemId = item is UserPost ? item.id : (item as PostModel).id;
      final isLeftIndex = itemId.hashCode.isEven;
      if (isLeftIndex != left) continue;

      double cardHeight = 200.0;

      if (item is UserPost) {
        // Stagger heights for user posts dynamically using stable hash index
        final heights = [270.0, 210.0, 250.0, 180.0];
        final hIdx = itemId.hashCode.abs() % heights.length;
        cardHeight = heights[hIdx];
      } else if (item is PostModel) {
        cardHeight = item.cardHeight;
      }

      columnWidgets.add(
        _FeedPostTile(
          key: ValueKey(itemId),
          item: item,
          cardHeight: cardHeight,
          isOnline: _isOnline,
        ),
      );
      columnWidgets.add(const SizedBox(height: 16));
    }
    return columnWidgets;
  }

  void _refreshFeed() {
    setState(() => _isRefreshing = true);
    PostStore.instance.syncOnlinePosts().then((_) {
      if (mounted) {
        setState(() {
          _shuffledPredefinedPosts.shuffle();
          _isRefreshing = false;
        });
      }
    });
  }

  Widget _buildShimmerGrid() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: const [
                    ShimmerContainer(height: 220, baseColor: Color(0xFF2A2A2E)),
                    SizedBox(height: 16),
                    ShimmerContainer(height: 140, baseColor: Color(0xFF2A2A2E)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: const [
                    ShimmerContainer(height: 140, baseColor: Color(0xFF2A2A2E)),
                    SizedBox(height: 16),
                    ShimmerContainer(height: 220, baseColor: Color(0xFF2A2A2E)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPage() {
    final userPosts = PostStore.instance.posts.where((p) => !p.savedInProfile).toList();
    final List<dynamic> allItems = [...userPosts, ..._shuffledPredefinedPosts];

    final filteredItems = allItems.where((item) {
      if (_searchQuery.trim().isEmpty) return false;
      final q = _searchQuery.toLowerCase();
      if (item is UserPost) {
        return item.title.toLowerCase().contains(q) ||
            item.body.toLowerCase().contains(q) ||
            (item.url?.toLowerCase().contains(q) ?? false);
      } else if (item is PostModel) {
        return (item.title?.toLowerCase().contains(q) ?? false) ||
            (item.description?.toLowerCase().contains(q) ?? false) ||
            (item.url?.toLowerCase().contains(q) ?? false);
      }
      return false;
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'search',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF7C7C81), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search items, titles, links...',
                        hintStyle: GoogleFonts.inter(
                          color: const Color(0xFF7C7C81),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = "";
                        });
                      },
                      child: const Icon(Icons.close, color: Colors.white70, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_searchQuery.trim().isEmpty) ...[
              Text(
                'POPULAR CATEGORIES',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7C7C81),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'jacket',
                  'panda',
                  'chic',
                  'street style',
                  'professional',
                  'meme',
                ].map((category) {
                  return ActionChip(
                    label: Text(category),
                    labelStyle: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    backgroundColor: const Color(0xFF1C1C1E),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      _searchController.text = category;
                      setState(() {
                        _searchQuery = category;
                      });
                    },
                  );
                }).toList(),
              ),
              const Expanded(
                child: SizedBox(),
              ),
            ] else ...[
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, color: Color(0xFF7C7C81), size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No items match your search',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF7C7C81),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: _buildStaggeredList(filteredItems, left: true),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    children: _buildStaggeredList(filteredItems, left: false),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────
//  Feed Post Tile — represents a single staggered tile inside feed columns
// ─────────────────────────────────────────────────────────────────────────────
class _FeedPostTile extends StatefulWidget {
  final dynamic item;
  final double cardHeight;
  final bool isOnline;

  const _FeedPostTile({
    super.key,
    required this.item,
    required this.cardHeight,
    required this.isOnline,
  });

  @override
  State<_FeedPostTile> createState() => _FeedPostTileState();
}

class _FeedPostTileState extends State<_FeedPostTile> {
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

  @override
  Widget build(BuildContext context) {
    final showShimmer = !widget.isOnline || _showShimmer;
    
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
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }



    if (showShimmer) {
      return ShimmerContainer(
        key: const ValueKey('shimmer'),
        height: widget.cardHeight,
        baseColor: const Color(0xFF2A2A2E),
      );
    }

    final itemId = widget.item is UserPost
        ? (widget.item as UserPost).id
        : (widget.item as PostModel).id;

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
              fit: BoxFit.fitWidth,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150,
                color: const Color(0xFF2A2A2E),
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 32),
                ),
              ),
            );
          } else {
            mediaWidget = Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFF2A2A2E),
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    post.title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: RichTextController.buildRichText(
                      post.body,
                      post.charStyles,
                      defaultStyle: GoogleFonts.inter(
                        color: const Color(0xFFAEAEB2),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
        } else {
          final post = widget.item as PostModel;
          
          // Removed custom border padding and accentColor backgrounds to enforce uniform layout
          Widget childWidget;
          if (post.mediaType == PostMediaType.video) {
            childWidget = RunningVideoPlayer(
              assetPath: post.mediaAssetPath,
            );
          } else {
            childWidget = Image.asset(
              post.mediaAssetPath,
              fit: BoxFit.fitWidth,
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


        final item = widget.item;
        final String titleText = item is UserPost ? item.title : (item as PostModel).title ?? '';
        final String userText = item is UserPost ? (item.username ?? 'gangster_vagas') : (item as PostModel).username ?? 'Unknown';
        final String? avatarAsset = item is UserPost ? null : (item as PostModel).avatarAssetPath;
        final String initial = userText.isNotEmpty ? userText[0].toUpperCase() : '?';
        final Color color = item is UserPost ? const Color(0xFF6B9BF7) : (item as PostModel).accentColor ?? const Color(0xFF7B61FF);
        final String sharesText = item is UserPost ? '0' : _format((item as PostModel).sharesCount);

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
          onLikeTap: () => PostStore.instance.toggleLikedPost(itemId),
          onSaveTap: () {
            PostStore.instance.toggleSavedSocialPost(itemId);
          },
          onShareTap: () async {
            if (item is UserPost) {
              await ShareHelper.sharePost(
                title: item.title,
                description: item.body,
                url: item.url,
                localImagePath: item.imagePath,
                localVideoPath: item.videoPath,
                author: 'You',
              );
            } else {
              await ShareHelper.sharePost(
                title: (item as PostModel).title ?? '',
                description: item.description,
                url: item.url,
                assetPath: item.mediaAssetPath,
                author: item.username ?? 'Unknown',
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
                painter: ArrowPainter(),
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

// --- Arrow Painter for Card 1 & 8 ---
class ArrowPainter extends CustomPainter {
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
