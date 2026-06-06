import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Interactive action row rendered at the bottom of every [PostCard].
///
/// Like and Save are locally toggled with optimistic count updates.
/// Share fires [onShare] — wire this to a share-sheet or Firestore call
/// once the backend is connected.
class PostActions extends StatefulWidget {
  final int initialLikes;
  final int initialSaves;
  final int initialShares;

  /// Called when the user taps the share button.
  final VoidCallback? onShare;

  const PostActions({
    super.key,
    required this.initialLikes,
    required this.initialSaves,
    required this.initialShares,
    this.onShare,
  });

  @override
  State<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends State<PostActions> {
  late bool _liked;
  late bool _saved;
  late int _likes;
  late int _saves;

  @override
  void initState() {
    super.initState();
    _liked = false;
    _saved = false;
    _likes = widget.initialLikes;
    _saves = widget.initialSaves;
  }

  /// Compact number formatter: 1000 → "1.0k", 1300 → "1.3k".
  String _format(int count) {
    if (count >= 1000) {
      final double val = count / 1000;
      return '${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // ── Like ────────────────────────────────────────────────────────
          _ActionButton(
            onTap: () => setState(() {
              _liked = !_liked;
              _likes += _liked ? 1 : -1;
            }),
            icon: _liked ? Icons.thumb_up_alt : Icons.thumb_up_alt_outlined,
            iconSize: 16,
            label: _format(_likes),
            active: _liked,
            activeColor: const Color(0xFF1565C0),
          ),

          // ── Save ────────────────────────────────────────────────────────
          _ActionButton(
            onTap: () => setState(() {
              _saved = !_saved;
              _saves += _saved ? 1 : -1;
            }),
            icon: _saved ? Icons.bookmark : Icons.bookmark_border,
            iconSize: 16,
            label: _format(_saves),
            active: _saved,
            activeColor: const Color(0xFF6A1B9A),
          ),

          // ── Share ───────────────────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onShare,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: const Icon(
                    Icons.reply,
                    size: 20,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _format(widget.initialShares),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Private helper button used by [PostActions].
class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final double iconSize;
  final String label;
  final bool active;
  final Color activeColor;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = active ? activeColor : const Color(0xFF333333);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
