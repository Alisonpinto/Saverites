import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/feed/feed_screen.dart';
import 'utils/translation_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _shimmerController;
  late AnimationController _formController;
  late Animation<double> _formFadeAnimation;
  late Animation<Offset> _formSlideAnimation;

  @override
  void initState() {
    super.initState();
    // Color shimmer controller (loops infinitely)
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Form entrance controller (runs once on page load)
    _formController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _formFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeIn),
      ),
    );

    // Staggered slide up offset
    _formSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _formController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _formController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shimmerController.dispose();
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Screen dimensions to calculate exact responsive metrics
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Proportional spacers — tightened so everything fits on one screen
    final topSpacer = screenHeight * 0.21;
    final middleSpacer = screenHeight * 0.07;
    final buttonSpacer = screenHeight * 0.05;
    final bottomSpacer = screenHeight * 0.03;

    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, _, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7C7C81),
                  Color(0xFF1A1A1B),
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.23, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: topSpacer),
                      // Logo — plain text, matching splash screen exactly
                      Text(
                        'memoria',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: middleSpacer),
                      // Animated inputs, buttons, and footer
                      AnimatedBuilder(
                        animation: _formController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _formFadeAnimation.value,
                            child: FractionalTranslation(
                              translation: _formSlideAnimation.value,
                              child: child,
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            // Form Container (~85% Width)
                            SizedBox(
                              width: screenWidth * 0.85,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Email Label
                                  Text(
                                    TranslationManager.t('email'),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFFFFFF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Email Input
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF333333),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.centerLeft,
                                    child: TextField(
                                      controller: _emailController,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: TranslationManager.t('enterEmail'),
                                        hintStyle: GoogleFonts.inter(
                                          color: const Color(0xFF515151),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  // Password Label
                                  Text(
                                    TranslationManager.t('password'),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFFFFFF),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Password Input
                                  Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF333333),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    alignment: Alignment.centerLeft,
                                    child: TextField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: TranslationManager.t('enterPassword'),
                                        hintStyle: GoogleFonts.inter(
                                          color: const Color(0xFF515151),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Buttons Container
                            SizedBox(
                              width: screenWidth * 0.85,
                              child: Column(
                                children: [
                                  // Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: TextButton(
                                      onPressed: () {
                                        if (_emailController.text == 'admin' &&
                                            _passwordController.text == 'admin') {
                                          Navigator.of(context).pushReplacement(
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation, secondaryAnimation) =>
                                                  const FeedScreen(),
                                              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                                final slideAnimation = Tween<Offset>(
                                                  begin: const Offset(0.0, 0.05),
                                                  end: Offset.zero,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeOutCubic,
                                                  ),
                                                );

                                                final fadeAnimation = Tween<double>(
                                                  begin: 0.0,
                                                  end: 1.0,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent: animation,
                                                    curve: Curves.easeIn,
                                                  ),
                                                );

                                                return FadeTransition(
                                                  opacity: fadeAnimation,
                                                  child: SlideTransition(
                                                    position: slideAnimation,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                              transitionDuration: const Duration(milliseconds: 600),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                TranslationManager.t('invalidCredentials'),
                                                style: GoogleFonts.inter(color: Colors.white),
                                              ),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFFFFF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: Text(
                                        TranslationManager.t('login'),
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF000000),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Google Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        backgroundColor: const Color(0xFFFFFFFF),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                      ),
                                      child: Stack(
                                        children: [
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Image.asset(
                                              'assets/images/google_logo.png',
                                              width: 22,
                                              height: 22,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.center,
                                            child: Text(
                                              TranslationManager.t('continueGoogle'),
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFF000000),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: buttonSpacer),
                            // Footer
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  TranslationManager.t('noAccount'),
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFFFFFFF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {},
                                  child: Text(
                                    TranslationManager.t('signUp'),
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFFFFFFFF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: const Color(0xFFFFFFFF),
                                      decorationThickness: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: bottomSpacer),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
