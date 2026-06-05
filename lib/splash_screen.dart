import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Fade-in controller (runs once)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Color shimmer controller (runs once)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    // Subtle pulsing scale/glow for background ambience
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Start sequences
    _controller.forward();
    _shimmerController.forward().then((_) {
      _navigateToHome();
    });
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Clean cross-fade transition
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1B),
      body: Stack(
        children: [
          // Subtle professional radial ambient glow behind the text
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8AB4F8).withValues(alpha: 0.07 * _glowAnimation.value),
                          const Color(0xFFC58AF9).withValues(alpha: 0.03 * _glowAnimation.value),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Shimmering Text Centered
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_controller, _shimmerController]),
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: const [
                          Color(0xFFFFFFFF),
                          Color(0xFF8AB4F8),
                          Color(0xFFC58AF9),
                          Color(0xFFFFFFFF),
                        ],
                        stops: const [0.0, 0.45, 0.55, 1.0],
                        begin: Alignment(-2.5 + 5.0 * _shimmerController.value, -1.0),
                        end: Alignment(-1.5 + 5.0 * _shimmerController.value, 1.0),
                      ).createShader(bounds);
                    },
                    child: Text(
                      'MEMORIA',
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 8.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
