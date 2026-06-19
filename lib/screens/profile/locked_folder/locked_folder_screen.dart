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
