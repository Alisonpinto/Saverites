import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fixed header bar rendered above the scrollable feed.
///
/// Contains a hamburger menu (with notification dot) and a pill search bar.
/// Both are wired with callbacks so parent screens can react without this
/// widget knowing about routing or state management.
class FeedHeader extends StatelessWidget {
  /// Called when the hamburger icon is tapped.
  final VoidCallback? onMenuTap;

  /// Called on every search query change.
  final ValueChanged<String>? onSearchChanged;

  const FeedHeader({
    super.key,
    this.onMenuTap,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      // Height = fixed inner height + status bar so content never
      // sits under the system status bar on any device.
      height: 62.0 + statusBarHeight,
      color: const Color(0xFF272729),
      padding: EdgeInsets.only(
        top: statusBarHeight > 0 ? statusBarHeight : 10,
        left: 16,
        right: 16,
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Hamburger + notification dot ────────────────────────────────
          GestureDetector(
            onTap: onMenuTap ?? () {},
            behavior: HitTestBehavior.opaque,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.menu, color: Colors.white, size: 26),
                Positioned(
                  right: -1,
                  top: -1,
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

          const SizedBox(width: 14),

          // ── Pill search bar ─────────────────────────────────────────────
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF8E8E93),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: onSearchChanged,
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
}
