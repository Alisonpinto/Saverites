import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/notification_model.dart';
import '../utils/translation_manager.dart';

/// A single row in the notification list.
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final bool isAlternate;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onDeny;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.isAlternate,
    this.onTap,
    this.onAccept,
    this.onDeny,
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

  /// Returns a friendly relative time string like "2m ago", "1h ago", "3d ago"
  String _relativeTime(String timestamp) {
    try {
      final DateTime dt = DateTime.parse(timestamp).toLocal();
      final Duration diff = DateTime.now().difference(dt);

      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return timestamp; // fallback to raw value
    }
  }

  /// Returns icon and color for the notification type badge
  (IconData, Color) _actionBadge(String actionType) {
    switch (actionType) {
      case 'liked':
        return (Icons.favorite_rounded, const Color(0xFFFF375F));
      case 'shared':
        return (Icons.share_rounded, const Color(0xFF7B61FF));
      case 'saved':
        return (Icons.bookmark_rounded, const Color(0xFF30D158));
      case 'commented':
        return (Icons.chat_bubble_rounded, const Color(0xFF0A84FF));
      case 'friend_request':
        return (Icons.person_add_rounded, const Color(0xFF6B9BF7));
      case 'friend_request_accepted':
        return (Icons.people_rounded, const Color(0xFF30D158));
      default:
        return (Icons.notifications_rounded, const Color(0xFFFF9F0A));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isFriendRequest = notification.actionType == 'friend_request';
    final (badgeIcon, badgeColor) = _actionBadge(notification.actionType ?? '');
    final String timeStr = _relativeTime(notification.timestamp);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: notification.isRead
              ? const Color(0xFF111113)
              : const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFriendRequest
                ? const Color(0xFF6B9BF7).withValues(alpha: 0.18)
                : notification.isRead
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.07),
            width: 1,
          ),
          boxShadow: notification.isRead
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(14, 13, 14, isFriendRequest ? 6 : 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar with action badge overlay ────────────────
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Avatar(notification: notification),
                      // Action type badge (bottom-right)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: badgeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF111113),
                              width: 2,
                            ),
                          ),
                          child: Icon(badgeIcon, size: 10, color: Colors.white),
                        ),
                      ),
                      // Unread blue dot (top-right)
                      if (!notification.isRead)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A84FF),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF111113), width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // ── Text content ────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User ID + timestamp
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                '@${notification.username}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF636366),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

                        // Action reason
                        Text(
                          _translatePreviewText(notification.previewText),
                          style: GoogleFonts.inter(
                            color: const Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Friend request action row ────────────────────────────
            if (isFriendRequest) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 13),
                child: Row(
                  children: [
                    // Accept
                    Expanded(
                      child: _ActionButton(
                        label: 'Accept',
                        icon: Icons.person_add_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF78E), Color(0xFFFFF78E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        textColor: Colors.black,
                        iconColor: Colors.black,
                        onTap: onAccept,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Decline
                    Expanded(
                      child: _ActionButton(
                        label: 'Decline',
                        icon: Icons.person_remove_rounded,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3A3A3C), Color(0xFF2C2C2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderColor: Colors.white.withValues(alpha: 0.1),
                        onTap: onDeny,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Premium action button ─────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color? borderColor;
  final Color textColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    this.borderColor,
    this.textColor = Colors.white,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
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
    // Priority 1: DiceBear seed → render SVG avatar
    if (notification.avatarSeed != null && notification.avatarSeed!.isNotEmpty) {
      return Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2A2A2E),
        ),
        clipBehavior: Clip.antiAlias,
        child: SvgPicture.network(
          'https://api.dicebear.com/9.x/notionists/svg?seed=${notification.avatarSeed}&backgroundColor=transparent',
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Center(
            child: Text(
              notification.avatarInitial.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // Priority 2: static asset path / Priority 3: initials fallback
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
