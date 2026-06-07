import 'package:flutter/material.dart';

class ShimmerContainer extends StatefulWidget {
  final double height;
  final Color baseColor;
  final double borderRadius;

  const ShimmerContainer({
    super.key,
    required this.height,
    required this.baseColor,
    this.borderRadius = 14,
  });

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final double progress = _shimmerController.value;
        return Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.baseColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                widget.baseColor,
                Colors.white.withValues(alpha: 0.08),
                widget.baseColor,
              ],
              stops: [
                (progress - 0.25).clamp(0.0, 1.0),
                progress.clamp(0.0, 1.0),
                (progress + 0.25).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}
