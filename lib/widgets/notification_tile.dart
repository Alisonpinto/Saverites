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

  @override
  Widget build(BuildContext context) {
    final bool isFriendRequest = notification.actionType == 'friend_request';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFriendRequest
                ? const Color(0xFF6B9BF7).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main row: avatar + text + timestamp ──────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(14, 14, 14, isFriendRequest ? 4 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with optional notification dot overlay
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Avatar(notification: notification),
                      if (!notification.isRead)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B9BF7),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF1A1A1C), width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  // Username + preview text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.username,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notification.timestamp,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF636366),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

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

            // ── Friend request action row ────────────────────────────────
            if (isFriendRequest) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
                    // Decline — subtle outlined style
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

// ── Premium action button ──────────────────────────────────────────────────────

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
