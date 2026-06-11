import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'screens/post/write_post_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
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

    // Normal flow with 2-second delay if not launched from share intent
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isLoggedIn ? const FeedScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      body: SafeArea(
        child: Align(
          alignment: const Alignment(0.0, -0.2),
          child: Image.asset(
            'assets/images/app_logo_memoria.png',
            height: 48,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
