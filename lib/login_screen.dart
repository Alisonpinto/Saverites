import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'avatar_setup_screen.dart';
import 'screens/feed/feed_screen.dart';
import 'utils/user_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginScreen — entry point for both Login and Register flows.
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Mode toggle
  bool _isRegisterMode = false;

  // Controllers – Login
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Controllers – Register
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regUserIdCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  // UI State
  bool _loginPasswordVisible = false;
  bool _regPasswordVisible = false;
  bool _regConfirmVisible = false;
  bool _isLoading = false;
  bool _checkingUserId = false;
  bool? _userIdAvailable; // null = unchecked, true = ok, false = taken
  Timer? _userIdDebounce;
  int _randomAttempts = 0;

  // Focus nodes
  final _loginEmailFocus = FocusNode();
  final _loginPasswordFocus = FocusNode();

  // Animations
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  // OAuth auth subscription listener
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _fadeCtrl.forward();
    _slideCtrl.forward();

    // Listen for User ID changes to debounce uniqueness check
    _regUserIdCtrl.addListener(_onUserIdChanged);

    // Listen for Supabase Auth state changes (useful for OAuth redirects)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final Session? session = data.session;
      final AuthChangeEvent event = data.event;
      if (session != null && (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed)) {
        if (mounted) {
          setState(() {
            _isLoading = true;
          });
        }
        try {
          // Pass the current mode so Google register on an existing account is blocked
          final authResult = await UserStore.instance.handleOAuthSession(
            session,
            isRegisterMode: _isRegisterMode,
          );
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            if (authResult.success) {
              _goAfterLogin();
            } else {
              final errorMsg = authResult.error ?? 'Google sign in failed.';
              // If the error is because the account already exists, offer a
              // one-tap switch to the Log In tab
              final isAlreadyRegistered = errorMsg.contains('already exists');
              if (isAlreadyRegistered) {
                _showAlreadyRegisteredError();
              } else {
                _showError(errorMsg);
              }
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _showError('Google sign in error: $e');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regUserIdCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    _loginEmailFocus.dispose();
    _loginPasswordFocus.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _userIdDebounce?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // ── User ID real-time uniqueness check ─────────────────────────────────────

  void _onUserIdChanged() {
    final text = _regUserIdCtrl.text.trim();
    _userIdDebounce?.cancel();

    if (text.length < 3) {
      setState(() {
        _userIdAvailable = null;
        _checkingUserId = false;
      });
      return;
    }

    setState(() {
      _checkingUserId = true;
      _userIdAvailable = null;
    });

    _userIdDebounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        final available = await UserStore.instance.isUserIdAvailable(text);
        if (mounted && _regUserIdCtrl.text.trim() == text) {
          setState(() {
            _userIdAvailable = available;
            _checkingUserId = false;
          });
        }
      } catch (e) {
        if (mounted && _regUserIdCtrl.text.trim() == text) {
          setState(() {
            _userIdAvailable = null;
            _checkingUserId = false;
          });
          _showError('Error checking User ID availability: $e');
        }
      }
    });
  }

  // ── Mode switch ─────────────────────────────────────────────────────────────

  void _switchMode(bool toRegister) {
    setState(() {
      _isRegisterMode = toRegister;
      _isLoading = false;
      _userIdAvailable = null;
      _checkingUserId = false;
      _randomAttempts = 0;
    });
    _slideCtrl.reset();
    _slideCtrl.forward();
  }

  // ── Navigation helpers ──────────────────────────────────────────────────────

  /// After LOGIN: go to avatar setup if not done yet, else feed.
  Future<void> _goAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final avatarDone = prefs.getBool('avatar_setup_done') ?? false;
    if (!mounted) return;
    if (avatarDone) {
      _pushFeed();
    } else {
      _pushAvatarSetup();
    }
  }

  /// After REGISTER: always show avatar setup.
  void _goAfterRegister() => _pushAvatarSetup();

  void _pushAvatarSetup() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const AvatarSetupScreen(),
        transitionsBuilder: (_, anim, _, child) => ColoredBox(
          color: const Color(0xFF0D0D0D),
          child: FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  void _pushFeed() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const FeedScreen(),
        transitionsBuilder: (_, anim, _, child) {
          return ColoredBox(
            color: const Color(0xFF0D0D0D),
            child: FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ── Snackbar helper ─────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: const Color(0xFFCF3A55),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ));
  }

  /// Shows a special snackbar when user tries to register with an already-used
  /// Google account. Includes a one-tap "Log In" action to switch tabs.
  void _showAlreadyRegisteredError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'This Google account is already registered.',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
        action: SnackBarAction(
          label: 'Log In',
          textColor: const Color(0xFFFAF096),
          onPressed: () {
            if (mounted) _switchMode(false);
          },
        ),
        backgroundColor: const Color(0xFFCF3A55),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: const Color(0xFF2ECC71),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ));
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _doLogin() async {
    final emailOrId = _loginEmailCtrl.text.trim();
    final password = _loginPasswordCtrl.text;

    if (emailOrId.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);
    final result = await UserStore.instance.login(
      emailOrUserId: emailOrId,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _goAfterLogin();
    } else {
      _showError(result.error ?? 'Login failed. Please try again.');
    }
  }

  Future<void> _doRegister() async {
    final name = _regNameCtrl.text.trim();
    final email = _regEmailCtrl.text.trim();
    final userId = _regUserIdCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    final confirm = _regConfirmCtrl.text;

    if (name.isEmpty || email.isEmpty || userId.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }
    if (_userIdAvailable == false) {
      _showError('User ID already exists. Please choose a different one.');
      return;
    }

    // If userId is valid length but availability wasn't checked yet, check now
    if (userId.length >= 3 && _userIdAvailable == null) {
      _userIdDebounce?.cancel();
      setState(() {
        _checkingUserId = true;
      });
      try {
        final available = await UserStore.instance.isUserIdAvailable(userId);
        if (!mounted) return;
        setState(() {
          _userIdAvailable = available;
          _checkingUserId = false;
        });
        if (!available) {
          _showError('User ID already exists. Please choose a different one.');
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _checkingUserId = false;
        });
        _showError('Error checking User ID availability: $e');
        return;
      }
    }

    setState(() => _isLoading = true);
    final result = await UserStore.instance.register(
      name: name,
      email: email,
      userId: userId,
      password: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      _showSuccess('Welcome to Saverites, ${result.user!.name}! 🎉');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) _goAfterRegister();
    } else {
      _showError(result.error ?? 'Registration failed. Please try again.');
    }
  }

  void _generateRandomId() {
    if (_randomAttempts >= 3) {
      _showError('You can only generate a random User ID 3 times.');
      return;
    }
    setState(() {
      _randomAttempts++;
    });
    final id = UserStore.generateRandomUserId();
    _regUserIdCtrl.text = id;
    _regUserIdCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: id.length),
    );
  }

  Future<void> _doGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await UserStore.instance.signInWithGoogleOAuth();
      // Browser handles the authentication. App links listener in main.dart
      // will trigger session restore when returning, or we restore session on resume.
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Google sign in error: $e');
      }
    }
  }

  // ── Forgot Password ─────────────────────────────────────────────────────────

  void _doForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        prefillEmail: _loginEmailCtrl.text.trim(),
        onSuccess: (email) {
          _showSuccess('Password reset email sent to $email. Check your inbox!');
        },
        onError: _showError,
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
    ));

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo ──────────────────────────────────────────────
                        Image.asset(
                          'assets/images/logo.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),

                        const SizedBox(height: 10),

                        // ── Tagline ───────────────────────────────────────────
                        Text(
                          _isRegisterMode
                              ? 'Create your account'
                              : 'Welcome back',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.2,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── Mode Toggle Pills ─────────────────────────────────
                        _buildTogglePills(),

                        const SizedBox(height: 28),

                        // ── Form ──────────────────────────────────────────────
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: child,
                          ),
                          child: _isRegisterMode
                              ? _RegisterForm(
                                  key: const ValueKey('register'),
                                  nameCtrl: _regNameCtrl,
                                  emailCtrl: _regEmailCtrl,
                                  userIdCtrl: _regUserIdCtrl,
                                  passwordCtrl: _regPasswordCtrl,
                                  confirmCtrl: _regConfirmCtrl,
                                  passwordVisible: _regPasswordVisible,
                                  confirmVisible: _regConfirmVisible,
                                  onTogglePassword: () => setState(
                                      () => _regPasswordVisible = !_regPasswordVisible),
                                  onToggleConfirm: () => setState(
                                      () => _regConfirmVisible = !_regConfirmVisible),
                                  checkingUserId: _checkingUserId,
                                  userIdAvailable: _userIdAvailable,
                                  onGenerateId: _generateRandomId,
                                  isLoading: _isLoading,
                                  onRegister: _doRegister,
                                  onSwitchToLogin: () => _switchMode(false),
                                  randomAttempts: _randomAttempts,
                                  onGoogleSignIn: _doGoogleSignIn,
                                )
                              : _LoginForm(
                                  key: const ValueKey('login'),
                                  emailCtrl: _loginEmailCtrl,
                                  passwordCtrl: _loginPasswordCtrl,
                                  emailFocus: _loginEmailFocus,
                                  passwordFocus: _loginPasswordFocus,
                                  passwordVisible: _loginPasswordVisible,
                                  onTogglePassword: () => setState(
                                      () => _loginPasswordVisible = !_loginPasswordVisible),
                                  isLoading: _isLoading,
                                  onLogin: _doLogin,
                                  onSwitchToRegister: () => _switchMode(true),
                                  onGoogleSignIn: _doGoogleSignIn,
                                  onForgotPassword: _doForgotPassword,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTogglePills() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _pill('Log In', !_isRegisterMode, () => _switchMode(false)),
          _pill('Sign Up', _isRegisterMode, () => _switchMode(true)),
        ],
      ),
    );
  }

  Widget _pill(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: active ? Colors.black : Colors.white.withValues(alpha: 0.55),
              fontSize: 14,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Login Form
// ─────────────────────────────────────────────────────────────────────────────

class _LoginForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final bool passwordVisible;
  final VoidCallback onTogglePassword;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onSwitchToRegister;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onForgotPassword;

  const _LoginForm({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.passwordVisible,
    required this.onTogglePassword,
    required this.isLoading,
    required this.onLogin,
    required this.onSwitchToRegister,
    required this.onGoogleSignIn,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Email or User ID'),
        const SizedBox(height: 8),
        _InputBox(
          controller: emailCtrl,
          focusNode: emailFocus,
          hint: 'you@example.com or your_user_id',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) =>
              FocusScope.of(context).requestFocus(passwordFocus),
        ),
        const SizedBox(height: 20),
        _FieldLabel('Password'),
        const SizedBox(height: 8),
        _InputBox(
          controller: passwordCtrl,
          focusNode: passwordFocus,
          hint: 'Enter your password',
          obscure: !passwordVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onLogin(),
          suffix: _EyeToggle(visible: passwordVisible, onTap: onTogglePassword),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: onForgotPassword,
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Log In',
          isLoading: isLoading,
          onTap: onLogin,
        ),
        const SizedBox(height: 16),
        _GoogleSignInButton(
          isLoading: isLoading,
          onTap: onGoogleSignIn,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            GestureDetector(
              onTap: onSwitchToRegister,
              child: Text(
                'Sign Up',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Register Form
// ─────────────────────────────────────────────────────────────────────────────

class _RegisterForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController userIdCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool passwordVisible;
  final bool confirmVisible;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final bool checkingUserId;
  final bool? userIdAvailable;
  final VoidCallback onGenerateId;
  final bool isLoading;
  final VoidCallback onRegister;
  final VoidCallback onSwitchToLogin;
  final int randomAttempts;
  final VoidCallback onGoogleSignIn;

  const _RegisterForm({
    super.key,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.userIdCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.passwordVisible,
    required this.confirmVisible,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.checkingUserId,
    required this.userIdAvailable,
    required this.onGenerateId,
    required this.isLoading,
    required this.onRegister,
    required this.onSwitchToLogin,
    required this.randomAttempts,
    required this.onGoogleSignIn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Full Name'),
        const SizedBox(height: 8),
        _InputBox(
          controller: nameCtrl,
          hint: 'Your display name',
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 20),

        _FieldLabel('Email Address'),
        const SizedBox(height: 8),
        _InputBox(
          controller: emailCtrl,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 20),

        // ── User ID field with generate button ──────────────────────────────
        _FieldLabel('User ID'),
        const SizedBox(height: 6),
        _buildUserIdRow(context),
        const SizedBox(height: 6),
        _buildUserIdStatus(),

        const SizedBox(height: 20),

        _FieldLabel('Password'),
        const SizedBox(height: 8),
        _InputBox(
          controller: passwordCtrl,
          hint: 'Min. 6 characters',
          obscure: !passwordVisible,
          textInputAction: TextInputAction.next,
          suffix: _EyeToggle(visible: passwordVisible, onTap: onTogglePassword),
        ),
        const SizedBox(height: 20),

        _FieldLabel('Confirm Password'),
        const SizedBox(height: 8),
        _InputBox(
          controller: confirmCtrl,
          hint: 'Repeat your password',
          obscure: !confirmVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onRegister(),
          suffix: _EyeToggle(visible: confirmVisible, onTap: onToggleConfirm),
        ),

        const SizedBox(height: 32),
        _PrimaryButton(
          label: 'Create Account',
          isLoading: isLoading,
          onTap: onRegister,
        ),
        const SizedBox(height: 16),
        _GoogleSignInButton(
          isLoading: isLoading,
          onTap: onGoogleSignIn,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Already have an account? ',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            GestureDetector(
              onTap: onSwitchToLogin,
              child: Text(
                'Log In',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserIdRow(BuildContext context) {
    // Border color based on availability status
    Color borderColor = Colors.white.withValues(alpha: 0.06);
    if (userIdAvailable == true) borderColor = const Color(0xFF2ECC71).withValues(alpha: 0.7);
    if (userIdAvailable == false) borderColor = const Color(0xFFCF3A55).withValues(alpha: 0.7);

    final bool canRandom = randomAttempts < 3;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: userIdCtrl,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. saverites_xyz',
                      hintStyle: GoogleFonts.inter(
                        color: const Color(0xFF515151),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      // Only allow lowercase letters, numbers, underscore
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                      LengthLimitingTextInputFormatter(20),
                    ],
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                ),
                // Status indicator on right side of input
                if (checkingUserId)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Color(0xFFFAF096),
                    ),
                  )
                else if (userIdAvailable == true)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF2ECC71), size: 18)
                else if (userIdAvailable == false)
                  const Icon(Icons.cancel_rounded,
                      color: Color(0xFFCF3A55), size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Generate random ID button
        GestureDetector(
          onTap: canRandom ? onGenerateId : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: canRandom ? 1.0 : 0.4,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF096),
                borderRadius: BorderRadius.circular(13),
                boxShadow: canRandom
                    ? [
                        BoxShadow(
                          color: const Color(0xFFFAF096).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.black,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Random (${3 - randomAttempts})',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserIdStatus() {
    if (userIdAvailable == true) {
      return Row(
        children: [
          const SizedBox(width: 2),
          const Icon(Icons.check, color: Color(0xFF2ECC71), size: 13),
          const SizedBox(width: 4),
          Text(
            'User ID is available!',
            style: GoogleFonts.inter(
              color: const Color(0xFF2ECC71),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else if (userIdAvailable == false) {
      return Row(
        children: [
          const SizedBox(width: 2),
          const Icon(Icons.close, color: Color(0xFFCF3A55), size: 13),
          const SizedBox(width: 4),
          Text(
            'User ID is already taken.',
            style: GoogleFonts.inter(
              color: const Color(0xFFCF3A55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    return Text(
      'Only lowercase letters, numbers, and underscore',
      style: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.3),
        fontSize: 11.5,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final void Function(String)? onSubmitted;

  const _InputBox({
    required this.controller,
    this.focusNode,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              onSubmitted: onSubmitted,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF515151),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          ?suffix,
        ],
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _EyeToggle({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: Colors.white.withValues(alpha: 0.35),
          size: 20,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: TextButton(
        onPressed: isLoading ? null : onTap,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.black,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          backgroundColor: const Color(0xFF141414),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/google-icon-logo-svgrepo-com.svg',
                    height: 18,
                    width: 18,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forgot Password Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  final String prefillEmail;
  final void Function(String email) onSuccess;
  final void Function(String error) onError;

  const _ForgotPasswordSheet({
    required this.prefillEmail,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final TextEditingController _emailCtrl;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      widget.onError('Please enter a valid email address.');
      return;
    }

    setState(() => _sending = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'saverites://reset-password',
      );
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
        widget.onSuccess(email);
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        widget.onError(e.message);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        widget.onError('Error: $e');
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24, left: 28, right: 28,
        bottom: bottom > 0 ? bottom + 24 : 36,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reset Password',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your account email and we'll send you a reset link.",
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _FieldLabel('Email Address'),
          const SizedBox(height: 10),
          _InputBox(
            controller: _emailCtrl,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendReset(),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: (_sending || _sent) ? null : _sendReset,
              style: TextButton.styleFrom(
                backgroundColor: _sent ? const Color(0xFF2ECC71) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.4),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.black,
                      ),
                    )
                  : _sent
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Email Sent!',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Send Reset Link',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
