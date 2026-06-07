import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A reusable premium card styled for the Memoria masonry layout.
///
/// Contains the media (image or video) at the top, optional custom borders,
/// and a light-grey reaction footer at the bottom.
class FeedCard extends StatelessWidget {
  final Widget imageWidget;
  final String likes;
  final String bookmarks;
  final String shares;
  final Color? cardColor;
  final EdgeInsets? imagePadding;
  final BorderRadius? imageBorderRadius;
  final bool isSaved; // To color bookmark icon if saved

  const FeedCard({
    super.key,
    required this.imageWidget,
    required this.likes,
    required this.bookmarks,
    required this.shares,
    this.cardColor,
    this.imagePadding,
    this.imageBorderRadius,
    this.isSaved = false,
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
                    Icon(
                      Icons.bookmark,
                      size: 16,
                      color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFF333333),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      bookmarks,
                      style: GoogleFonts.inter(
                        color: isSaved ? const Color(0xFFBF5AF2) : const Color(0xFF333333),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Share Section
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
