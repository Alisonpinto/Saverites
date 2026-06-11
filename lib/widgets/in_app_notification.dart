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
  /// - [showMedia]: Whether to show the large bottom media preview (matches save vs like/share templates).
  static Future<void> show({
    required String body,
    String? imagePath,
    String? assetImagePath,
    bool showMedia = true,
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

  const InAppNotificationBanner({
    super.key,
    required this.body,
    this.imagePath,
    this.assetImagePath,
    required this.showMedia,
    required this.onDismiss,
  });

  @override
  State<InAppNotificationBanner> createState() => _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // overshoot/spring effect
    ));

    _controller.forward();

    // Auto dismiss after 4 seconds
    _dismissTimer = Timer(const Duration(seconds: 4), () {
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

  @override
  Widget build(BuildContext context) {
    Widget? mediaWidget;
    if (widget.showMedia) {
      if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
        mediaWidget = Image.file(
          File(widget.imagePath!),
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFD9D9D9),
            width: double.infinity,
            height: 150,
          ),
        );
      } else if (widget.assetImagePath != null && widget.assetImagePath!.isNotEmpty) {
        mediaWidget = Image.asset(
          widget.assetImagePath!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: 150,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFD9D9D9),
            width: double.infinity,
            height: 150,
          ),
        );
      } else {
        // Default template fallback: solid grey container matching push_notification.png
        mediaWidget = Container(
          color: const Color(0xFFD9D9D9),
          width: double.infinity,
          height: 150,
        );
      }
    }

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _dragOffsetY += details.primaryDelta!;
          if (_dragOffsetY > 0) _dragOffsetY = 0; // prevent dragging down too much
        });
      },
      onVerticalDragEnd: (details) {
        if (_dragOffsetY < -25 || details.primaryVelocity! < -100) {
          _dismiss();
        } else {
          setState(() {
            _dragOffsetY = 0.0;
          });
        }
      },
      child: Transform.translate(
        offset: Offset(0, _dragOffsetY),
        child: SlideTransition(
          position: _offsetAnimation,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: App Icon & "memoria • now"
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD9D9D9),
                          shape: BoxShape.circle,
                        ),
                        // Soft logo visual representation
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/app_logo_memoria.png',
                              width: 16,
                              height: 16,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'memoria',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' • now',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Middle Section: Notification Body Text
                  Text(
                    widget.body,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  // Bottom Section: Media Block
                  if (widget.showMedia && mediaWidget != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: mediaWidget,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
