import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/translation_manager.dart';

import '../../models/saved_item_model.dart';
import '../../widgets/app_bottom_navigation.dart';
import 'settings_screen.dart';

/// User profile screen.
///
/// Shows profile info, stats, a tab switcher between Social Save / Self Save,
/// a searchable masonry grid, and an expandable FAB for content creation.
///
/// Replace the static sample lists with Firestore streams when the backend
/// is connected. The [SavedItemModel] fields map directly to Firestore fields.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeTab = 0; // 0 = Social Save, 1 = Self Save
  bool _fabExpanded = false;

  // ── Sample saved items ─────────────────────────────────────────────────────
  //
  // Replace with StreamBuilder<List<SavedItemModel>> from Firestore.
  // Social saves populate when a user bookmarks a feed post.
  // Self saves populate when the user taps "Write a Post" or "Save a Item".

  static final List<SavedItemModel> _socialSaves = [
    SavedItemModel(
      id: 'ss1',
      cardHeight: 130,
      source: SaveSource.social,
      savedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    SavedItemModel(
      id: 'ss2',
      cardHeight: 160,
      source: SaveSource.social,
      savedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    SavedItemModel(
      id: 'ss3',
      cardHeight: 150,
      source: SaveSource.social,
      savedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    SavedItemModel(
      id: 'ss4',
      cardHeight: 110,
      source: SaveSource.social,
      savedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  static final List<SavedItemModel> _selfSaves = [
    SavedItemModel(
      id: 'se1',
      cardHeight: 140,
      source: SaveSource.self,
      savedAt: DateTime.now().subtract(const Duration(hours: 1)),
      title: 'My first post',
    ),
    SavedItemModel(
      id: 'se2',
      cardHeight: 120,
      source: SaveSource.self,
      savedAt: DateTime.now().subtract(const Duration(days: 3)),
      title: 'Saved reference',
    ),
  ];

  List<SavedItemModel> get _activeItems =>
      _activeTab == 0 ? _socialSaves : _selfSaves;

  @override
  Widget build(BuildContext context) {
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
        body: Stack(
          children: [
            // ── Main content column ────────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _ProfileHeader(),

                // Avatar + stats
                _ProfileInfo(),

                const SizedBox(height: 20),

                // Search bar
                const _ProfileSearchBar(),

                const SizedBox(height: 20),

                // Tab switcher
                _ProfileTabBar(
                  activeTab: _activeTab,
                  onTabChanged: (i) => setState(() => _activeTab = i),
                ),

                const SizedBox(height: 16),

                // Masonry grid
                Expanded(
                  child: _SavedContentGrid(items: _activeItems),
                ),
              ],
            ),

            // ── Blur Overlay ───────────────────────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_fabExpanded,
                child: AnimatedOpacity(
                  opacity: _fabExpanded ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: () => setState(() => _fabExpanded = false),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Expandable FAB overlay ─────────────────────────────────────
            _ProfileFabOverlay(
              expanded: _fabExpanded,
              onToggle: () => setState(() => _fabExpanded = !_fabExpanded),
              onWritePost: () {
                setState(() => _fabExpanded = false);
                // TODO: navigate to write-a-post flow
              },
              onSaveItem: () {
                setState(() => _fabExpanded = false);
                // TODO: navigate to save-an-item flow
              },
            ),
          ],
        ),

        // Bottom nav — profile tab active
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: 3,
          onTabChanged: (index) {
            if (index != 3) {
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 4),
          Text(
            TranslationManager.t('profile'),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const SettingsScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    final slideAnimation = Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
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
                  transitionDuration: const Duration(milliseconds: 600),
                ),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: Colors.white,
              size: 24,
            ),
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Profile info: avatar + username + stats ───────────────────────────────────

class _ProfileInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar circle
          Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF2A2A2E),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/panda.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Username + join date + stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'gangster_vagas',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '20 june 024',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatItem(value: '6.7k', label: TranslationManager.t('likes')),
                  const SizedBox(width: 28),
                  _StatItem(value: '170', label: TranslationManager.t('posts')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF8E8E93),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _ProfileSearchBar extends StatelessWidget {
  const _ProfileSearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF3A3A3C), width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.search, color: Color(0xFF8E8E93), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: TranslationManager.t('findAnything'),
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF8E8E93),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _ProfileTabBar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const _ProfileTabBar({
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _TabItem(
            label: TranslationManager.t('socialSave'),
            isActive: activeTab == 0,
            onTap: () => onTabChanged(0),
          ),
          const SizedBox(width: 28),
          _TabItem(
            label: TranslationManager.t('selfSave'),
            isActive: activeTab == 1,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 2,
            width: isActive ? (label.length * 8.2) : 0,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Saved content grid (masonry 2-col) ────────────────────────────────────────

class _SavedContentGrid extends StatelessWidget {
  final List<SavedItemModel> items;

  const _SavedContentGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          TranslationManager.t('nothingSaved'),
          style: GoogleFonts.inter(
            color: const Color(0xFF48484A),
            fontSize: 14,
          ),
        ),
      );
    }

    // Split into two columns alternating
    final List<SavedItemModel> left = [];
    final List<SavedItemModel> right = [];
    for (int i = 0; i < items.length; i++) {
      if (i.isEven) {
        left.add(items[i]);
      } else {
        right.add(items[i]);
      }
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _GridColumn(items: left)),
          const SizedBox(width: 10),
          Expanded(child: _GridColumn(items: right)),
        ],
      ),
    );
  }
}

class _GridColumn extends StatelessWidget {
  final List<SavedItemModel> items;

  const _GridColumn({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _SavedCard(item: items[i]),
          if (i < items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SavedCard extends StatelessWidget {
  final SavedItemModel item;

  const _SavedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: item.mediaAssetPath != null
          ? Image.asset(
              item.mediaAssetPath!,
              height: item.cardHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : Container(
              height: item.cardHeight,
              width: double.infinity,
              // Light grey matching the Figma design skeleton cards
              color: const Color(0xFFC0BEBB),
            ),
    );
  }
}

// ── Expandable FAB overlay ────────────────────────────────────────────────────

class _ProfileFabOverlay extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onWritePost;
  final VoidCallback onSaveItem;

  const _ProfileFabOverlay({
    required this.expanded,
    required this.onToggle,
    required this.onWritePost,
    required this.onSaveItem,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      right: 16,
      bottom: 16 + bottomPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action items — slide in when expanded
          AnimatedSlide(
            offset: expanded ? Offset.zero : const Offset(0, 0.3),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: AnimatedOpacity(
              opacity: expanded ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FabAction(
                    label: TranslationManager.t('writePost'),
                    icon: Icons.edit_note_rounded,
                    onTap: onWritePost,
                  ),
                  const SizedBox(height: 10),
                  _FabAction(
                    label: TranslationManager.t('saveItem'),
                    icon: Icons.bookmark_add_outlined,
                    onTap: onSaveItem,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // "+" toggle button
          GestureDetector(
            onTap: onToggle,
            child: AnimatedRotation(
              turns: expanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _FabAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          // Icon button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2E),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
