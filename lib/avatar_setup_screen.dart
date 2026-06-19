import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/feed/feed_screen.dart';
import 'widgets/dice_avatar.dart';

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

  final TextEditingController _seedController = TextEditingController();
  final FocusNode _seedFocus = FocusNode();
  String _currentSeed = 'memoria';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialSeed();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _seedFocus.addListener(_onFocusChange);

    _entryCtrl.forward();
  }

  void _onFocusChange() {
    if (!_seedFocus.hasFocus) {
      final val = _seedController.text.trim();
      if (val.isNotEmpty && val != _currentSeed) {
        setState(() {
          _currentSeed = val;
        });
      }
    }
  }

  Future<void> _loadInitialSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeed = prefs.getString('dice_bear_seed');
    if (savedSeed != null && savedSeed.isNotEmpty) {
      setState(() {
        _currentSeed = savedSeed;
        _seedController.text = savedSeed;
      });
    } else {
      _randomizeSeed();
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _seedController.dispose();
    _seedFocus.removeListener(_onFocusChange);
    _seedFocus.dispose();
    super.dispose();
  }

  void _randomizeSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    final newSeed = String.fromCharCodes(Iterable.generate(
        8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    setState(() {
      _currentSeed = newSeed;
      _seedController.text = newSeed;
    });
  }

  Future<void> _saveAndContinue() async {
    setState(() => _isSaving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('avatar_setup_done', true);
      await prefs.setString('dice_bear_seed', _currentSeed);
      DiceAvatar.seedNotifier.value = _currentSeed;
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
                // Top bar
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

                const Spacer(),

                // Avatar preview
                Center(
                  child: SizedBox(
                    width: 140,
                    height: 140,
                    child: SvgPicture.network(
                      'https://api.dicebear.com/9.x/notionists/svg?seed=$_currentSeed&backgroundColor=transparent',
                      fit: BoxFit.contain,
                      placeholderBuilder: (BuildContext context) => const CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),

                const Spacer(),

                // Customizer
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Avatar Name / Seed',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _seedController,
                        focusNode: _seedFocus,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF1C1C1E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.casino, color: Colors.white),
                            onPressed: _randomizeSeed,
                            tooltip: 'Randomize',
                          ),
                        ),
                        onChanged: (val) {
                          if (val.isNotEmpty && val.endsWith(' ')) {
                            final trimmed = val.trim();
                            if (trimmed != _currentSeed) {
                              setState(() {
                                _currentSeed = trimmed;
                              });
                            }
                          }
                        },
                        onSubmitted: (val) {
                          if (val.isNotEmpty) {
                            setState(() {
                              _currentSeed = val.trim();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Save button
                Container(
                  color: const Color(0xFF111113),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
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
                                  const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
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


