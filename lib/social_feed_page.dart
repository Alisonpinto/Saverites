import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark outer bezel mock
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40), // Premium mobile screen rounding
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF121212), // Main feed body dark background
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  // Header Block (Responsive Height, Figma color #272729)
                  _buildHeader(context),
                  // Masonry Feed
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column
                          Expanded(
                            child: Column(
                              children: [
                                // Card 1: Outfit Card (Tall)
                                _buildOutfitCard(
                                  title: 'Trend Huntss',
                                  imagePath: 'assets/images/outfit.png',
                                  likes: '1k',
                                  bookmarks: '1.3k',
                                  shares: '100',
                                  height: 270,
                                  arrow: true,
                                ),
                                const SizedBox(height: 12),
                                // Card 3: Meme Card (Medium)
                                _buildMemeCard(
                                  query: 'rekha ji not so sanskari pics',
                                  likes: '1k',
                                  bookmarks: '1.3k',
                                  shares: '100',
                                  height: 210,
                                ),
                                const SizedBox(height: 12),
                                // Card 5: Second Jacket Card (Short)
                                _buildJacketCard(
                                  likes: '1.2k',
                                  bookmarks: '850',
                                  shares: '45',
                                  height: 150,
                                ),
                                const SizedBox(height: 12),
                                // Card 6: Second Panda Card (Tall, Cyan Border)
                                _buildPandaCard(
                                  text: 'chill\nTIME',
                                  borderColor: const Color(0xFF00B0FF),
                                  likes: '920',
                                  bookmarks: '1.1k',
                                  shares: '60',
                                  height: 250,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Right Column
                          Expanded(
                            child: Column(
                              children: [
                                // Card 2: Jacket Card (Short)
                                _buildJacketCard(
                                  likes: '1k',
                                  bookmarks: '1.3k',
                                  shares: '100',
                                  height: 150,
                                ),
                                const SizedBox(height: 12),
                                // Card 4: Panda Card (Tall, Pink Border)
                                _buildPandaCard(
                                  text: 'peace\nBRO!!',
                                  borderColor: const Color(0xFFE52E5E),
                                  likes: '1k',
                                  bookmarks: '1.3k',
                                  shares: '100',
                                  height: 250,
                                ),
                                const SizedBox(height: 12),
                                // Card 7: Second Meme Card (Medium)
                                _buildMemeCard(
                                  query: 'flutter app look professional in 5 minutes',
                                  likes: '800',
                                  bookmarks: '500',
                                  shares: '25',
                                  height: 210,
                                ),
                                const SizedBox(height: 12),
                                // Card 8: Second Outfit Card (Tall)
                                _buildOutfitCard(
                                  title: 'Street Style',
                                  imagePath: 'assets/images/outfit.png',
                                  likes: '1.5k',
                                  bookmarks: '2k',
                                  shares: '180',
                                  height: 270,
                                  arrow: false,
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
              bottomNavigationBar: _buildBottomNavBar(),
            ),
          ),
        ),
      ),
    );
  }

  // --- Header Panel (Figma #272729, Responsive status bar top-padding) ---
  Widget _buildHeader(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // Calculate final responsive height including status bar height (standard 85 on desktop)
    final double finalHeaderHeight = 85.0 + (statusBarHeight > 0 ? statusBarHeight : 0);

    return Container(
      height: finalHeaderHeight,
      color: const Color(0xFF272729),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10, // Safe padding fallback
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hamburger Menu Icon with Red Notification Dot
          GestureDetector(
            onTap: () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 28,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Pill Search Bar with white outline
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(
                  color: Colors.white,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Find anything',
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
          ),
        ],
      ),
    );
  }

  // --- Outfit Card (Card 1 & 8) ---
  Widget _buildOutfitCard({
    required String title,
    required String imagePath,
    required String likes,
    required String bookmarks,
    required String shares,
    required double height,
    required bool arrow,
  }) {
    return FeedCard(
      likes: likes,
      bookmarks: bookmarks,
      shares: shares,
      imageWidget: Stack(
        children: [
          Image.asset(
            imagePath,
            fit: BoxFit.cover,
            height: height,
            width: double.infinity,
          ),
          // Serif Italic Text Overlay
          Positioned.fill(
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
          ),
        ],
      ),
    );
  }

  // --- Jacket Card (Card 2 & 5) ---
  Widget _buildJacketCard({
    required String likes,
    required String bookmarks,
    required String shares,
    required double height,
  }) {
    return FeedCard(
      likes: likes,
      bookmarks: bookmarks,
      shares: shares,
      imageWidget: Image.asset(
        'assets/images/jacket.png',
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
      ),
    );
  }

  // --- Meme Card (Card 3 & 7) ---
  Widget _buildMemeCard({
    required String query,
    required String likes,
    required String bookmarks,
    required String shares,
    required double height,
  }) {
    return FeedCard(
      likes: likes,
      bookmarks: bookmarks,
      shares: shares,
      imageWidget: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Image.asset(
            'assets/images/meme.png',
            fit: BoxFit.cover,
            height: height,
            width: double.infinity,
          ),
          // Google search mockup overlay
          Padding(
            padding: const EdgeInsets.all(8.0),
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
                  // Google brand header
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
                  // Mock search query
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
                  // Tab list mock
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
          ),
        ],
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

  // --- Panda Card (Card 4 & 6) ---
  Widget _buildPandaCard({
    required String text,
    required Color borderColor,
    required String likes,
    required String bookmarks,
    required String shares,
    required double height,
  }) {
    return FeedCard(
      likes: likes,
      bookmarks: bookmarks,
      shares: shares,
      cardColor: borderColor, // Custom border highlight shell
      imagePadding: const EdgeInsets.only(top: 6.0, left: 6.0, right: 6.0),
      imageBorderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(18),
      ),
      imageWidget: Stack(
        children: [
          Image.asset(
            'assets/images/panda.png',
            fit: BoxFit.cover,
            height: height,
            width: double.infinity,
          ),
          // Stylized handwriting text
          Positioned(
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
          ),
        ],
      ),
    );
  }

  // --- Custom Navigation Bar (Figma #272729) ---
  Widget _buildBottomNavBar() {
    return Container(
      height: 72,
      color: const Color(0xFF272729),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () => setState(() => _currentTab = 0),
            icon: Icon(
              _currentTab == 0 ? Icons.home : Icons.home_outlined,
              color: _currentTab == 0 ? Colors.white : const Color(0xFF8E8E93),
              size: 28,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _currentTab = 1),
            icon: Icon(
              Icons.search,
              color: _currentTab == 1 ? Colors.white : const Color(0xFF8E8E93),
              size: 28,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _currentTab = 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _currentTab == 2 ? Icons.notifications : Icons.notifications_none_outlined,
                  color: _currentTab == 2 ? Colors.white : const Color(0xFF8E8E93),
                  size: 28,
                ),
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 15,
                      minHeight: 15,
                    ),
                    child: Text(
                      '1',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _currentTab = 3),
            icon: Icon(
              _currentTab == 3 ? Icons.bookmark : Icons.bookmark_border,
              color: _currentTab == 3 ? Colors.white : const Color(0xFF8E8E93),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Reusable Card Wrapper ---
class FeedCard extends StatelessWidget {
  final Widget imageWidget;
  final String likes;
  final String bookmarks;
  final String shares;
  final Color? cardColor;
  final EdgeInsets? imagePadding;
  final BorderRadius? imageBorderRadius;

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.likes,
    required this.bookmarks,
    required this.shares,
    this.cardColor,
    this.imagePadding,
    this.imageBorderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: imagePadding ?? EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: imageBorderRadius ??
                  const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
              child: imageWidget,
            ),
          ),
          // Light Grey Reaction Footer
          Container(
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFD9D9D9),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Likes Section
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.thumb_up_alt_outlined, size: 16, color: Color(0xFF333333)),
                    const SizedBox(width: 4),
                    Text(
                      likes,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Bookmarks Section
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark, size: 16, color: Color(0xFF333333)),
                    const SizedBox(width: 4),
                    Text(
                      bookmarks,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Share Section (Flipped reply arrow)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: const Icon(Icons.reply, size: 20, color: Color(0xFF333333)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      shares,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Arrow Painter for Card 1 ---
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

    // Arrowhead drawing
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
