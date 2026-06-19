import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../utils/post_store.dart';
import '../profile_screen.dart'; // To reuse _ProfileMasonryGrid if possible, but _ProfileMasonryGrid is private. We can copy it or make it public.

class LockedFolderScreen extends StatefulWidget {
  const LockedFolderScreen({super.key});

  @override
  State<LockedFolderScreen> createState() => _LockedFolderScreenState();
}

class _LockedFolderScreenState extends State<LockedFolderScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    PostStore.instance.postsNotifier.addListener(_onPostsChanged);
  }

  void _onPostsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    PostStore.instance.postsNotifier.removeListener(_onPostsChanged);
    super.dispose();
  }

  void _toggleSelection(String id) {
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

  @override
  Widget build(BuildContext context) {
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
            // Gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF2A2A2F),
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
                  // Sticky Header Row
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
                            splashRadius: 20,
                          )
                        else
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                            padding: const EdgeInsets.all(8),
                            splashRadius: 20,
                          ),
                        const SizedBox(width: 4),
                        Text(
                          _isSelectionMode ? '${_selectedIds.length} Selected' : 'Locked Folder',
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
                              PostStore.instance.unlockUserPosts(_selectedIds);
                              setState(() {
                                _isSelectionMode = false;
                                _selectedIds.clear();
                              });
                            },
                            icon: Icon(Icons.lock_open, color: _selectedIds.isEmpty ? Colors.grey : Colors.white, size: 24),
                            tooltip: 'Unlock Items',
                          ),
                          IconButton(
                            onPressed: _selectedIds.isEmpty ? null : () {
                              PostStore.instance.removeUserPosts(_selectedIds);
                              setState(() {
                                _isSelectionMode = false;
                                _selectedIds.clear();
                              });
                            },
                            icon: Icon(Icons.delete, color: _selectedIds.isEmpty ? Colors.grey : Colors.redAccent, size: 24),
                            tooltip: 'Delete Items',
                          ),
                        ]
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<List<UserPost>>(
                      valueListenable: PostStore.instance.postsNotifier,
                      builder: (context, savedUserPosts, _) {
                        final lockedPosts = savedUserPosts.where((p) => p.isLocked).toList();
                        if (lockedPosts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  'Nothing here yet',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        // We will use the same public ProfileMasonryGrid.
                        // I will need to make _ProfileMasonryGrid public in profile_screen.dart,
                        // or I can just re-implement a simple grid here. For simplicity and code reuse,
                        // I will make it public as ProfileMasonryGrid in profile_screen.dart.
                        return ProfileMasonryGrid(
                          items: lockedPosts,
                          isOnline: true,
                          isSelectionMode: _isSelectionMode,
                          selectedIds: _selectedIds,
                          onSelectToggle: _toggleSelection,
                          onLongPress: _onLongPress,
                        );
                      },
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
