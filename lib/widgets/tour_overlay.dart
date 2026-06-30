import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TourStep: Describes one tooltip callout
// ─────────────────────────────────────────────────────────────────────────────
class TourStep {
  /// Alignment of the highlight circle (where the arrow points)
  final Alignment targetAlignment;

  /// X, Y offset from the target to nudge the circle position (in fraction of screen)
  final double targetX;
  final double targetY;

  /// Where the callout card appears: 'top', 'bottom', 'center'
  final String calloutPosition;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const TourStep({
    required this.targetX,
    required this.targetY,
    this.calloutPosition = 'bottom',
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.targetAlignment = Alignment.bottomCenter,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  TourOverlay: overlays on any screen with step-by-step callout bubbles
// ─────────────────────────────────────────────────────────────────────────────
class TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onDone;

  const TourOverlay({
    super.key,
    required this.steps,
    required this.onDone,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() async {
    await _animCtrl.reverse();
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      _animCtrl.forward();
    } else {
      widget.onDone();
    }
  }

  void _skip() => widget.onDone();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;

    // Position of the spotlight circle (fraction of screen)
    final cx = step.targetX * size.width;
    final cy = step.targetY * size.height;
    const double spotRadius = 36;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Dark scrim with spotlight cutout ───────────────────────────
          // NOTE: Uses saveLayer+BlendMode.clear — reliable on all Android GPUs.
          // Path.combine(PathOperation.difference) can fail silently on some
          // devices, rendering the entire screen gray instead of cutting a hole.
          Positioned.fill(
            child: _SpotlightOverlay(
              cx: cx,
              cy: cy,
              radius: spotRadius,
            ),
          ),

          // ── Pulsing ring around spotlight ──────────────────────────────
          Positioned(
            left: cx - spotRadius,
            top: cy - spotRadius,
            child: _PulsingRing(
              radius: spotRadius,
              color: step.iconColor,
            ),
          ),

          // ── Callout card ───────────────────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              alignment: Alignment.center,
              child: _CalloutCard(
                step: step,
                currentIndex: _currentStep,
                totalSteps: widget.steps.length,
                isLast: isLast,
                onNext: _next,
                onSkip: _skip,
                screenSize: size,
                spotX: cx,
                spotY: cy,
                spotRadius: spotRadius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Spotlight painter — darkens screen except a circle around the target.
//  Uses saveLayer + BlendMode.clear for broad Android GPU compatibility.
//  Path.combine(PathOperation.difference) is NOT used because it fails
//  silently on many Android devices, producing a solid gray overlay.
// ─────────────────────────────────────────────────────────────────────────────
class _SpotlightOverlay extends StatelessWidget {
  final double cx, cy, radius;
  const _SpotlightOverlay({required this.cx, required this.cy, required this.radius});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      isComplex: true,
      painter: _SpotlightPainter(cx: cx, cy: cy, radius: radius),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final double cx, cy, radius;
  _SpotlightPainter({required this.cx, required this.cy, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    // Save a new compositing layer so BlendMode.clear punches a real hole.
    final layerRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.saveLayer(layerRect, Paint());

    // Step 1: fill the entire screen with the dark scrim.
    canvas.drawRect(
      layerRect,
      Paint()..color = Colors.black.withValues(alpha: 0.72),
    );

    // Step 2: erase a circle to reveal the content beneath (the "spotlight").
    // BlendMode.clear sets all pixels in the circle to fully transparent.
    canvas.drawCircle(
      Offset(cx, cy),
      radius + 10,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.cx != cx || old.cy != cy || old.radius != radius;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulsing ring around spotlight
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingRing extends StatefulWidget {
  final double radius;
  final Color color;
  const _PulsingRing({required this.radius, required this.color});

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = (widget.radius + 10) * 2;
    return SizedBox(
      width: d,
      height: d,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => CustomPaint(
          painter: _RingPainter(
            radius: widget.radius + 10,
            color: widget.color.withValues(alpha: _anim.value * 0.8),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double radius;
  final Color color;
  _RingPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Callout card that describes the highlighted element
// ─────────────────────────────────────────────────────────────────────────────
class _CalloutCard extends StatelessWidget {
  final TourStep step;
  final int currentIndex;
  final int totalSteps;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Size screenSize;
  final double spotX, spotY, spotRadius;

  const _CalloutCard({
    required this.step,
    required this.currentIndex,
    required this.totalSteps,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
    required this.screenSize,
    required this.spotX,
    required this.spotY,
    required this.spotRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Place card above or below the spotlight
    final cardWidth = screenSize.width - 48.0;
    const cardPad = 24.0;
    final mediaPadding = MediaQuery.of(context).padding;

    // Determine vertical placement
    final placeBelow = step.calloutPosition == 'bottom' || spotY < screenSize.height * 0.55;
    final cardTop = placeBelow
        ? spotY + spotRadius + 28
        : spotY - spotRadius - 28 - 230; // rough card height

    // Clamp to stay on screen, accounting for status bar and bottom safe area
    // If the layout bounds are not fully resolved (e.g., screenSize is 0.0),
    // ensure the limits do not cross to avoid throwing an ArgumentError.
    final minLimit = mediaPadding.top + 16.0;
    final maxLimit = (screenSize.height - mediaPadding.bottom - 260.0).clamp(minLimit, double.infinity);
    final safeTop = cardTop.clamp(minLimit, maxLimit);

    return Positioned(
      left: cardPad,
      top: safeTop,
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: step.iconColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: step.iconColor.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: step.iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(step.icon, color: step.iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSkip,
                  child: Text(
                    'Skip',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7C7C81),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Description ───────────────────────────────────────────
            Text(
              step.description,
              style: GoogleFonts.inter(
                color: const Color(0xFFCCCCCC),
                fontSize: 14,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),

            // ── Progress dots + Next button ───────────────────────────
            Row(
              children: [
                // Dots
                Row(
                  children: List.generate(totalSteps, (i) {
                    final isActive = i == currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(right: 5),
                      width: isActive ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive
                            ? step.iconColor
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                // Next / Done button
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: step.iconColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLast ? 'Got it ✓' : 'Next →',
                      style: GoogleFonts.inter(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TourManager: controls first-time tour display via SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
class TourManager {
  static Future<bool> shouldShowTour(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('tour_seen_$tourKey') ?? false);
  }

  static Future<void> markTourSeen(String tourKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tour_seen_$tourKey', true);
  }

  /// Call this to reset all tours (useful for testing)
  static Future<void> resetAllTours() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('tour_seen_'));
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
