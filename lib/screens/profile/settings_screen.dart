import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../login_screen.dart';
import '../../utils/translation_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _currentLanguage = 'English';
  final TextEditingController _feedbackController = TextEditingController();
  int _charCount = 0;



  // Helper to translate keys dynamically with fallback to English
  String _t(String key) {
    return TranslationManager.t(key);
  }

  @override
  void initState() {
    super.initState();
    _feedbackController.addListener(() {
      setState(() {
        _charCount = _feedbackController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  // Helper to build section labels
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        color: const Color(0xFF7C7C81),
        fontSize: 15,
        fontWeight: FontWeight.w500, // Medium
      ),
    );
  }

  // Helper to build rows inside card list
  Widget _buildRow({
    required IconData icon,
    required String label,
    String? value,
    bool isDestructive = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final Color textColor = isDestructive ? const Color(0xFFEB4335) : Colors.white;
    final Color iconColor = isDestructive ? const Color(0xFFEB4335) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500, // Medium
                  ),
                ),
              ),
              if (value != null) ...[
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7C7C81),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive ? const Color(0xFFEB4335) : const Color(0xFF7C7C81),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom Divider
  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.08), // Thin line, rgba(255,255,255,0.08)
    );
  }

  // Custom premium toggle switch: White track, black thumb
  Widget _buildCustomToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _notificationsEnabled = !_notificationsEnabled;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: _notificationsEnabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: _notificationsEnabled ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black, // Black thumb
            ),
          ),
        ),
      ),
    );
  }

  // Show premium dark bottom sheet to choose language with Search filter
  void _showLanguageSelector(BuildContext context) {
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Filter languages based on search query
            final filteredLanguages = TranslationManager.allLanguages
                .where((lang) => lang.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Language',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF7C7C81), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search Bar inside Language Bottom Sheet
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.search, color: Color(0xFF7C7C81), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                            onChanged: (val) {
                              setModalState(() {
                                searchQuery = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search language...',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF7C7C81),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
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
                  const SizedBox(height: 20),
                  // Flexible, scrollable list of filtered languages
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (filteredLanguages.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No languages found',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF7C7C81),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              for (int i = 0; i < filteredLanguages.length; i++) ...[
                                _buildLanguageOption(context, filteredLanguages[i]),
                                if (i < filteredLanguages.length - 1) _buildDivider(),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageOption(BuildContext context, String lang) {
    final isSelected = _currentLanguage == lang;
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close language sheet
        
        // Show premium loader overlay
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Translating to $lang...',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        // Fetch translations dynamically
        final success = await TranslationManager.loadLanguage(lang);
        
        if (!context.mounted) return;
        
        // Pop the loader overlay
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }

        if (success) {
          setState(() {
            _currentLanguage = lang;
          });
          TranslationManager.currentLanguageNotifier.value = lang;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Language changed to $lang',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to translate to $lang. Please try again.',
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              lang,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // Navigate to information detail screens using premium animations
  void _navigateToDetail(String title, Widget content) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            DetailInfoScreen(title: title, content: content),
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
  }

  // Content Builders for details pages
  Widget _buildHelpContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: _t('helpQ1'),
          body: _t('helpA1'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('helpQ2'),
          body: _t('helpA2'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('helpQ3'),
          body: _t('helpA3'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDevelopersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: _t('devQ1'),
          body: _t('devA1'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('devQ2'),
          body: _t('devA2'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildMemoriaContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: _t('memoriaQ1'),
          body: _t('memoriaA1'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('memoriaQ2'),
          body: _t('memoriaA2'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTermsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: _t('termsQ1'),
          body: _t('termsA1'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('termsQ2'),
          body: _t('termsA2'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('termsQ3'),
          body: _t('termsA3'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPrivacyContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: _t('privacyQ1'),
          body: _t('privacyA1'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('privacyQ2'),
          body: _t('privacyA2'),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: _t('privacyQ3'),
          body: _t('privacyA3'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoCard({required String title, required String body}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              color: const Color(0xFFC0BEBB),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: TranslationManager.currentLanguageNotifier,
      builder: (context, currentLang, _) {
        _currentLanguage = currentLang;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF121212), // Same background as the profile screen
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER ──────────────────────────────────────────────────
                  Container(
                    color: const Color(0xFF121212),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top > 0
                          ? MediaQuery.of(context).padding.top
                          : 10,
                      bottom: 12,
                      left: 8,
                      right: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _t('title'), // Translated "Settings"
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // Header -> First section spacing

                  // ── SCROLLABLE SETTINGS CONTENT ─────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Preferences Section ─────────────────────────────
                          _buildSectionLabel(_t('preferences')),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                _buildRow(
                                  icon: Icons.notifications_none_outlined,
                                  label: _t('notifications'),
                                  trailing: _buildCustomToggle(),
                                ),
                                _buildDivider(),
                                _buildRow(
                                  icon: Icons.language_outlined,
                                  label: _t('language'),
                                  value: _currentLanguage,
                                  onTap: () => _showLanguageSelector(context),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24), // Spacing between cards

                          // ── Support Section ─────────────────────────────────
                          _buildSectionLabel(_t('support')),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                _buildRow(
                                  icon: Icons.help_outline_rounded,
                                  label: _t('helpSupport'),
                                  onTap: () => _navigateToDetail(_t('helpSupport'), _buildHelpContent()),
                                ),
                                _buildDivider(),
                                _buildRow(
                                  icon: Icons.people_outline_rounded,
                                  label: _t('aboutDevs'),
                                  onTap: () => _navigateToDetail(_t('aboutDevs'), _buildDevelopersContent()),
                                ),
                                _buildDivider(),
                                _buildRow(
                                  icon: Icons.info_outline_rounded,
                                  label: _t('aboutMemoria'),
                                  onTap: () => _navigateToDetail(_t('aboutMemoria'), _buildMemoriaContent()),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24), // Spacing between cards

                          // ── Legal Section ───────────────────────────────────
                          _buildSectionLabel(_t('legal')),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                _buildRow(
                                  icon: Icons.description_outlined,
                                  label: _t('terms'),
                                  onTap: () => _navigateToDetail(_t('terms'), _buildTermsContent()),
                                ),
                                _buildDivider(),
                                _buildRow(
                                  icon: Icons.shield_outlined,
                                  label: _t('privacy'),
                                  onTap: () => _navigateToDetail(_t('privacy'), _buildPrivacyContent()),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24), // Spacing between cards

                          // ── Account Section ─────────────────────────────────
                          _buildSectionLabel(_t('account')),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: _buildRow(
                              icon: Icons.logout_outlined,
                              label: _t('logout'),
                              isDestructive: true,
                              onTap: () async {
                                final navigator = Navigator.of(context);
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setBool('isLoggedIn', false);
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _t('loggingOut'),
                                      style: GoogleFonts.inter(color: Colors.white),
                                    ),
                                    backgroundColor: const Color(0xFFEB4335),
                                    duration: const Duration(milliseconds: 800),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                                Future.delayed(const Duration(milliseconds: 800), () {
                                  navigator.pushAndRemoveUntil(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          const LoginScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                                          child: child,
                                        );
                                      },
                                      transitionDuration: const Duration(milliseconds: 500),
                                    ),
                                    (route) => false,
                                  );
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 24), // Spacing between cards

                          // ── Feedback Section ────────────────────────────────
                          _buildSectionLabel(_t('feedback')),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _feedbackController,
                                  maxLines: 5,
                                  maxLength: 500,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _t('placeholder'),
                                    hintStyle: GoogleFonts.inter(
                                      color: const Color(0xFF7C7C81),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    counterText: "",
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$_charCount/500",
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF7C7C81),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      height: 44,
                                      child: TextButton(
                                        onPressed: () {
                                          final text = _feedbackController.text.trim();
                                          if (text.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  _t('enterFeedback'),
                                                  style: GoogleFonts.inter(color: Colors.black),
                                                ),
                                                backgroundColor: Colors.white,
                                                behavior: SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                            return;
                                          }
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                _t('feedbackSubmitted'),
                                                style: GoogleFonts.inter(color: Colors.white),
                                              ),
                                              backgroundColor: Colors.green,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          _feedbackController.clear();
                                          FocusScope.of(context).unfocus();
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(22), // Pill shape
                                          ),
                                          padding: EdgeInsets.zero,
                                        ),
                                        child: Text(
                                          _t('submit'),
                                          style: GoogleFonts.inter(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500, // Inter Medium
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32), // Bottom safe padding
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── DETAIL SCREEN FOR GENERAL INFORMATION ─────────────────────────────────────
class DetailInfoScreen extends StatelessWidget {
  final String title;
  final Widget content;

  const DetailInfoScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF121212), // Same background as settings
        child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER ──────────────────────────────────────────────────
                  Container(
                    color: const Color(0xFF121212),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top > 0
                          ? MediaQuery.of(context).padding.top
                          : 10,
                      bottom: 12,
                      left: 8,
                      right: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20), // Header -> Content spacing

                  // ── CONTENT ─────────────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}
