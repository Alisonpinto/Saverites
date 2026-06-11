import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Animated Illustrated Avatar
//  Open Peeps-inspired minimal SVG avatar
//  with continuously animating hair
// ─────────────────────────────────────────────
class AnimatedAvatar extends StatefulWidget {
  final double size;
  const AnimatedAvatar({super.key, this.size = 88});

  @override
  State<AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<AnimatedAvatar>
    with TickerProviderStateMixin {
  late AnimationController _hairController;
  late AnimationController _floatController;
  late Animation<double> _hairSwayAnim;
  late Animation<double> _hairBreathAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    // Hair sway: gentle left-right, period 3.5s
    _hairController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    _hairSwayAnim = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _hairController, curve: Curves.easeInOutSine),
    );

    _hairBreathAnim = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _hairController, curve: Curves.easeInOutSine),
    );

    // Floating: tiny vertical bob, period 4s
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _hairController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hairController, _floatController]),
      builder: (ctx, xb) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _AvatarPainter(
                hairSway: _hairSwayAnim.value,
                hairBreath: _hairBreathAnim.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final double hairSway;
  final double hairBreath;

  const _AvatarPainter({
    required this.hairSway,
    required this.hairBreath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Outline paint ────────────────────────────
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final skinPaint = Paint()
      ..color = const Color(0xFFF5E6D3)
      ..style = PaintingStyle.fill;

    final hairPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    // ── Body (shirt) ─────────────────────────────
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + 36),
        width: 54,
        height: 36,
      ),
      const Radius.circular(18),
    );
    canvas.drawRRect(bodyRect, fillPaint);
    canvas.drawRRect(bodyRect, outlinePaint);

    // ── Neck ─────────────────────────────────────
    final neckPath = Path()
      ..moveTo(cx - 8, cy + 20)
      ..lineTo(cx + 8, cy + 20)
      ..lineTo(cx + 7, cy + 28)
      ..lineTo(cx - 7, cy + 28)
      ..close();
    canvas.drawPath(neckPath, skinPaint);

    // ── Head (face) ──────────────────────────────
    final headCenter = Offset(cx, cy + 4);
    const headRadius = 24.0;

    canvas.drawCircle(headCenter, headRadius, skinPaint);
    canvas.drawCircle(headCenter, headRadius, outlinePaint);

    // ── Eyes ─────────────────────────────────────
    final eyePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 8, cy + 2), width: 5, height: 6),
      eyePaint,
    );
    // Right eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 8, cy + 2), width: 5, height: 6),
      eyePaint,
    );

    // Eye highlights
    final highlightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 6.5, cy + 1), 1.2, highlightPaint);
    canvas.drawCircle(Offset(cx + 9.5, cy + 1), 1.2, highlightPaint);

    // ── Eyebrows ──────────────────────────────────
    final browPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx - 11, cy - 5),
      Offset(cx - 5, cy - 6.5),
      browPaint,
    );
    canvas.drawLine(
      Offset(cx + 5, cy - 6.5),
      Offset(cx + 11, cy - 5),
      browPaint,
    );

    // ── Nose ─────────────────────────────────────
    final nosePaint = Paint()
      ..color = const Color(0xFFD4A574)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 8, height: 5),
      0,
      math.pi,
      false,
      nosePaint,
    );

    // ── Mouth (small smile) ───────────────────────
    final mouthPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(cx - 6, cy + 14)
      ..quadraticBezierTo(cx, cy + 18, cx + 6, cy + 14);
    canvas.drawPath(mouthPath, mouthPaint);

    // ── Hair (animated) ───────────────────────────
    canvas.save();
    // Pivot animation at crown of head
    canvas.translate(cx, cy - 18);
    canvas.rotate(hairSway);
    canvas.scale(hairBreath, hairBreath);
    canvas.translate(-cx, -(cy - 18));

    // Main hair blob (curly top)
    final hairPath = Path();
    hairPath.moveTo(cx - 20, cy - 5);
    // Left side sweep
    hairPath.cubicTo(
      cx - 28, cy - 18,
      cx - 24, cy - 36,
      cx - 10, cy - 34,
    );
    // Top center wave
    hairPath.cubicTo(
      cx - 4, cy - 40,
      cx + 4, cy - 40,
      cx + 10, cy - 34,
    );
    // Right side sweep
    hairPath.cubicTo(
      cx + 24, cy - 36,
      cx + 28, cy - 18,
      cx + 20, cy - 5,
    );
    // Close back along head
    hairPath.cubicTo(
      cx + 14, cy - 8,
      cx - 14, cy - 8,
      cx - 20, cy - 5,
    );
    hairPath.close();

    canvas.drawPath(hairPath, hairPaint);
    canvas.drawPath(hairPath, outlinePaint);

    // Small strand detail on right
    final strandPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    final strand = Path()
      ..moveTo(cx + 16, cy - 28)
      ..cubicTo(cx + 20, cy - 24, cx + 22, cy - 16, cx + 19, cy - 8);
    canvas.drawPath(strand, strandPaint);

    canvas.restore();

    // ── Ears ─────────────────────────────────────
    canvas.drawCircle(Offset(cx - 24, cy + 4), 5.5, skinPaint);
    canvas.drawCircle(Offset(cx - 24, cy + 4), 5.5, outlinePaint);
    canvas.drawCircle(Offset(cx + 24, cy + 4), 5.5, skinPaint);
    canvas.drawCircle(Offset(cx + 24, cy + 4), 5.5, outlinePaint);
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.hairSway != hairSway || old.hairBreath != hairBreath;
}
