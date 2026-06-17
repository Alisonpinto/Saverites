import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'avatar_setup_screen.dart';
import 'login_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/post/write_post_screen.dart';
import 'utils/user_store.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeIn,
      ),
    );

    _animController.forward();

    _navigateToHome();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _navigateToHome() async {
    const shareChannel = MethodChannel('com.example.memoria_flutter/share_intent');
    Map<String, dynamic>? sharedData;
    try {
      final initialData = await shareChannel.invokeMethod('getSharedIntent');
      if (initialData != null) {
        sharedData = Map<String, dynamic>.from(initialData);
      }
    } catch (e) {
      debugPrint("Error fetching initial shared intent: $e");
    }

    if (!mounted) return;

    // Restore session from SharedPreferences
    await UserStore.instance.loadSession();

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!mounted) return;

    if (sharedData != null && isLoggedIn) {
      // Bypasses splash delay and opens WritePostScreen directly on top of FeedScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const FeedScreen()),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WritePostScreen(isSaveItem: true, sharedData: sharedData),
        ),
      );
      return;
    }

    // Normal flow with 1.5-second delay if not launched from share intent
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (!isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // Already logged in — check if avatar setup was done
    final avatarDone = prefs.getBool('avatar_setup_done') ?? false;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => avatarDone ? const FeedScreen() : const AvatarSetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'me',
                        softWrap: false,
                        maxLines: 1,
                        style: GoogleFonts.jotiOne(
                          fontSize: 36,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                Text(
                  'moria',
                  softWrap: false,
                  maxLines: 1,
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
