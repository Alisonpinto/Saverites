import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttermoji/fluttermoji.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/feed/feed_screen.dart';

/// AvatarSetupScreen — shown once after login/registration
/// so the user can personalise their Fluttermoji before entering the feed.
///
/// The screen can be skipped via "Skip for now" — the avatar will just be
/// the default one. A saved avatar is stored locally by the fluttermoji
/// package in SharedPreferences and is shown across the app automatically.
class AvatarSetupScreen extends StatefulWidget {
  final bool isFromProfile;
  const AvatarSetupScreen({super.key, this.isFromProfile = false});

  @override
  State<AvatarSetupScreen> createState() => _AvatarSetupScreenState();
}

class _AvatarSetupScreenState extends State<AvatarSetupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      // Encode and persist the avatar string — fluttermoji handles SharedPrefs
      // internally, but we also set a flag so we don't show this screen again.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('avatar_setup_done', true);

      // Optionally encode and save for cross-device sync later:
      // final avatarString = await encodeMySVGtoString();
      // await prefs.setString('fluttermoji_string', avatarString);
    } catch (e) {
      debugPrint('AvatarSetupScreen save error: $e');
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (widget.isFromProfile) {
      Navigator.of(context).pop();
    } else {
      _navigateToFeed();
    }
  }

  void _skip() {
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool('avatar_setup_done', true),
    );
    _navigateToFeed();
  }

  void _navigateToFeed() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const FeedScreen(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Column(
              children: [
                // ── Top bar ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Avatar',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Make it look like you',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // Skip or Close button
                      widget.isFromProfile
                          ? IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 24),
                              onPressed: () => Navigator.of(context).pop(),
                              splashRadius: 22,
                            )
                          : TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                'Skip',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Avatar circle preview ─────────────────────────────────────
                Center(
                  child: _AvatarPreviewRing(
                    child: FluttermojiCircleAvatar(
                      radius: 70,
                      backgroundColor: const Color(0xFF1C1C1E),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Customizer ────────────────────────────────────────────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF111113),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: FluttermojiCustomizer(
                        scaffoldWidth: MediaQuery.of(context).size.width,
                        autosave: true,
                        theme: FluttermojiThemeData(
                          primaryBgColor: const Color(0xFF111113),
                          secondaryBgColor: const Color(0xFF1C1C1E),
                          iconColor: Colors.white.withValues(alpha: 0.5),
                          selectedIconColor: Colors.white,
                          unselectedIconColor: Colors.white.withValues(alpha: 0.3),
                          labelTextStyle: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          boxDecoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                              width: 1,
                            ),
                          ),
                          selectedTileDecoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                          ),
                          unselectedTileDecoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Save button ───────────────────────────────────────────────
                Container(
                  color: const Color(0xFF111113),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.check_circle_rounded,
                                      color: Colors.black, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.isFromProfile ? 'Save & Return' : 'Save Avatar & Continue',
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Decorative glow ring around the avatar preview circle
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarPreviewRing extends StatelessWidget {
  final Widget child;
  const _AvatarPreviewRing({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF4A4A4A),
            Color(0xFFE5E5EA),
            Color(0xFF1A1A1B),
            Color(0xFF4A4A4A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0C),
          shape: BoxShape.circle,
        ),
        child: ClipOval(child: child),
      ),
    );
  }
}
