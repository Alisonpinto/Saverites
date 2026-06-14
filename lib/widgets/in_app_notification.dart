import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class InAppNotificationHelper {
  static OverlayEntry? _currentEntry;
  static Timer? _autoDismissTimer;

  /// Shows the custom in-app push notification banner.
  ///
  /// - [body]: The text message to display.
  /// - [imagePath]: Path to a local media file on disk (for user posts).
  /// - [assetImagePath]: Path to a bundled asset image (for predefined posts).
  /// - [showMedia]: Whether to show the large bottom media preview (new post style).
  /// - [avatarInitial]: Single letter to show in the round avatar when no image is available.
  /// - [avatarColor]: Background color of the round avatar circle.
  /// - [avatarImagePath]: Local file path to a profile picture for the avatar.
  /// - [avatarAssetPath]: Asset path to a profile picture for the avatar.
  static Future<void> show({
    required String body,
    String? imagePath,
    String? assetImagePath,
    bool showMedia = false,
    String avatarInitial = 'M',
    Color avatarColor = const Color(0xFF7B61FF),
    String? avatarImagePath,
    String? avatarAssetPath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;
    } catch (e) {
      debugPrint("Error reading notification setting: $e");
    }

    final context = MyApp.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final overlay = MyApp.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    // Cancel existing timer and remove previous banner if active
    _autoDismissTimer?.cancel();
    if (_currentEntry != null) {
      try {
        _currentEntry!.remove();
      } catch (_) {}
      _currentEntry = null;
    }

    _currentEntry = OverlayEntry(
      builder: (context) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: InAppNotificationBanner(
                  body: body,
                  imagePath: imagePath,
                  assetImagePath: assetImagePath,
                  showMedia: showMedia,
                  avatarInitial: avatarInitial,
                  avatarColor: avatarColor,
                  avatarImagePath: avatarImagePath,
                  avatarAssetPath: avatarAssetPath,
                  onDismiss: () {
                    _currentEntry?.remove();
                    _currentEntry = null;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_currentEntry!);
  }
}

class InAppNotificationBanner extends StatefulWidget {
  final String body;
  final String? imagePath;
  final String? assetImagePath;
  final bool showMedia;
  final VoidCallback onDismiss;
  final String avatarInitial;
  final Color avatarColor;
  final String? avatarImagePath;
  final String? avatarAssetPath;

  const InAppNotificationBanner({
    super.key,
    required this.body,
    this.imagePath,
    this.assetImagePath,
    required this.showMedia,
    required this.onDismiss,
    this.avatarInitial = 'M',
    this.avatarColor = const Color(0xFF7B61FF),
    this.avatarImagePath,
    this.avatarAssetPath,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Auto dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      _dismiss();
    });
  }

  Future<void> _dismiss() async {
    _dismissTimer?.cancel();
    if (mounted) {
      await _controller.reverse();
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Builds the round avatar — profile pic > asset > initials fallback.
  Widget _buildAvatar() {
    const double size = 36.0;

    // Try local file avatar
    if (widget.avatarImagePath != null && widget.avatarImagePath!.isNotEmpty) {
      final f = File(widget.avatarImagePath!);
      if (f.existsSync()) {
        return ClipOval(
          child: Image.file(
            f,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    // Try asset avatar (e.g. panda.png)
    if (widget.avatarAssetPath != null && widget.avatarAssetPath!.isNotEmpty) {
      return ClipOval(
        child: Image.asset(
          widget.avatarAssetPath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, e, _) => _initialsAvatar(size),
        ),
      );
    }

    return _initialsAvatar(size);
  }

  Widget _initialsAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: widget.avatarColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.avatarInitial.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// Builds the large image preview area (new-post style).
  Widget? _buildMediaPreview() {
    if (!widget.showMedia) return null;

    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150,
          errorBuilder: (_, e, _) => _greyMediaPlaceholder(),
        ),
      );
    }

    if (widget.assetImagePath != null && widget.assetImagePath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          widget.assetImagePath!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150,
          errorBuilder: (_, e, _) => _greyMediaPlaceholder(),
        ),
      );
    }

    // Solid grey fallback matching the reference screenshot
    return _greyMediaPlaceholder();
  }

  Widget _greyMediaPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: const Color(0xFFD9D9D9),
        width: double.infinity,
        height: 150,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaWidget = _buildMediaPreview();

    return GestureDetector(
      onTap: _dismiss,
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffsetY += details.primaryDelta!;
          if (_dragOffsetY > 0) _dragOffsetY = 0;
        });
      },
      onVerticalDragEnd: (details) {
        if (_dragOffsetY < -20 || (details.primaryVelocity ?? 0) < -120) {
          _dismiss();
        } else {
          setState(() => _dragOffsetY = 0.0);
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffsetY),
        child: SlideTransition(
          position: _offsetAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  // Pure black pill matching reference screenshots
                  color: const Color(0xFF050505),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header row: avatar  •  "memoria  •  now" ────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Round profile avatar
                        _buildAvatar(),
                        const SizedBox(width: 10),
                        // App name
                        Text(
                          'memoria',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        // Separator dot
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF888888),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        // Timestamp
                        Text(
                          'now',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF888888),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 9),

                    // ── Body text ───────────────────────────────────────────
                    Text(
                      widget.body,
                      maxLines: widget.showMedia ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),

                    // ── Image preview (new-post style only) ─────────────────
                    if (mediaWidget != null) ...[
                      const SizedBox(height: 10),
                      mediaWidget,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
