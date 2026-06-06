import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/notification_model.dart';
import '../utils/translation_manager.dart';

/// A single row in the notification list.
///
/// Pass [isAlternate] based on the row index to produce the
/// alternating background pattern that matches the Figma design.
///
/// This widget is purely presentational — all interaction handling
/// (tap → open notification detail) belongs in the parent screen.
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  /// If true, renders with the secondary background (#1C1C1E).
  /// If false, renders with the primary background (#121212).
  final bool isAlternate;

  /// Optional tap handler — wire to a detail screen or mark-as-read call.
  final VoidCallback? onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isAlternate,
    this.onTap,
  });

  String _translatePreviewText(String text) {
    if (text == 'liked your post') return TranslationManager.t('likedYourPost');
    if (text == 'started following you') return TranslationManager.t('startedFollowing');
    if (text == 'saved your post') return TranslationManager.t('savedYourPost');
    if (text == 'shared your post') return TranslationManager.t('sharedYourPost');
    if (text == 'commented: "This is stunning 🔥"') return TranslationManager.t('commentedStunning');
    if (text == 'commented: "Where was this taken?"') return TranslationManager.t('commentedWhere');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: isAlternate ? const Color(0xFF1C1C1E) : const Color(0xFF121212),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────────
            _Avatar(notification: notification),

            const SizedBox(width: 14),

            // ── Username + preview text ──────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${notification.username} ',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                        TextSpan(
                          text: _translatePreviewText(notification.previewText),
                          style: GoogleFonts.inter(
                            color: const Color(0xFFAEAEB2),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // ── Timestamp + unread dot ───────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  notification.timestamp,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF8E8E93),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (!notification.isRead) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF1744),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar helper ─────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final NotificationModel notification;

  const _Avatar({required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: notification.avatarColor,
        image: notification.avatarAssetPath != null
            ? DecorationImage(
                image: AssetImage(notification.avatarAssetPath!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: notification.avatarAssetPath == null
          ? Text(
              notification.avatarInitial.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
