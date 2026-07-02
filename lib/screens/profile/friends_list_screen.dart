import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/user_store.dart';
import '../../widgets/dice_avatar.dart';
import 'profile_screen.dart';

class FriendsListScreen extends StatefulWidget {
  /// Pass the user_id (username string) whose friends list to show.
  final String? userId;

  const FriendsListScreen({super.key, this.userId});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _Friend {
  final String userId;
  final String name;
  final String avatarSeed;

  const _Friend({
    required this.userId,
    required this.name,
    required this.avatarSeed,
  });
}

class _FriendsListScreenState extends State<FriendsListScreen>
    with SingleTickerProviderStateMixin {
  List<_Friend> _friends = [];
  List<_Friend> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadFriends();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final uid = widget.userId ?? UserStore.instance.currentUser?.userId;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 1. Resolve user_id string → UUID
      final pRes = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('user_id', uid)
          .maybeSingle();

      if (pRes == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final String myUuid = pRes['id'] as String;

      // 2. Load people this user follows
      final followRows = await Supabase.instance.client
          .from('user_follows')
          .select('followed_id')
          .eq('follower_id', myUuid);

      if (followRows.isEmpty) {
        if (mounted) setState(() { _friends = []; _filtered = []; _loading = false; });
        _fadeCtrl.forward();
        return;
      }

      final followedIds = followRows
          .map<String>((r) => r['followed_id'] as String)
          .toList();

      // 3. Fetch their profiles
      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('user_id, name, avatar_seed')
          .inFilter('id', followedIds);

      final friends = profileRows.map<_Friend>((r) {
        return _Friend(
          userId: r['user_id'] as String? ?? '',
          name: r['name'] as String? ?? r['user_id'] as String? ?? '',
          avatarSeed: r['avatar_seed'] as String? ?? r['user_id'] as String? ?? 'memoria',
        );
      }).toList();

      friends.sort((a, b) => a.name.compareTo(b.name));

      if (mounted) {
        setState(() {
          _friends = friends;
          _filtered = friends;
          _loading = false;
        });
        _fadeCtrl.forward();
      }
    } catch (e) {
      debugPrint('FriendsListScreen error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      _searchQuery = q.trim().toLowerCase();
      _filtered = _searchQuery.isEmpty
          ? _friends
          : _friends
              .where((f) =>
                  f.name.toLowerCase().contains(_searchQuery) ||
                  f.userId.toLowerCase().contains(_searchQuery))
              .toList();
    });
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final isMyProfile = widget.userId == null ||
        widget.userId == UserStore.instance.currentUser?.userId;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Stack(
          children: [
            // ── Gradient top accent ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 260,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1037), Color(0xFF0A0A0A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── App bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 20),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMyProfile ? 'My Friends' : 'Friends',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (!_loading)
                                Text(
                                  '${_friends.length} connection${_friends.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF7C7C81),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Refresh button
                        GestureDetector(
                          onTap: () {
                            _fadeCtrl.reset();
                            _loadFriends();
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: const Icon(Icons.refresh_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Search bar ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Icon(Icons.search_rounded,
                              color: Colors.white.withValues(alpha: 0.35),
                              size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearch,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search friends…',
                                hintStyle: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _onSearch('');
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Icon(Icons.close_rounded,
                                    color: Colors.white.withValues(alpha: 0.4),
                                    size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Content ─────────────────────────────────────────
                  Expanded(
                    child: _loading
                        ? _buildShimmerList()
                        : _friends.isEmpty
                            ? _buildEmptyState(isMyProfile)
                            : _filtered.isEmpty
                                ? _buildNoResults()
                                : FadeTransition(
                                    opacity: _fadeAnim,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _filtered.length,
                                      itemBuilder: (ctx, i) =>
                                          _buildFriendTile(_filtered[i], i),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendTile(_Friend friend, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (ctx, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (ctx, anim, _) => ProfileScreen(
                username: friend.userId,
                showBottomNav: false,
                showBackButton: true,
              ),
              transitionsBuilder: (ctx, anim, _, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 350),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF7B61FF).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: SvgPicture.network(
                  'https://api.dicebear.com/9.x/notionists/svg?seed=${friend.avatarSeed}&backgroundColor=transparent',
                  fit: BoxFit.cover,
                  placeholderBuilder: (_) => DiceAvatar(
                    radius: 26,
                    seed: friend.avatarSeed,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name & handle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalize(friend.name),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${friend.userId}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF636366),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Chevron
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            _shimmerCircle(52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBar(120, 14),
                  const SizedBox(height: 6),
                  _shimmerBar(80, 11),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCircle(double size) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: v * 0.12),
        ),
      ),
    );
  }

  Widget _shimmerBar(double width, double height) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: v * 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMyProfile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF7B61FF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF7B61FF).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.people_alt_outlined,
                  color: Color(0xFF7B61FF), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              isMyProfile ? 'No friends yet' : 'No connections yet',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMyProfile
                  ? 'Connect with people on Saverites to see them here.'
                  : 'This user hasn\'t connected with anyone yet.',
              style: GoogleFonts.inter(
                color: const Color(0xFF636366),
                fontSize: 13,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              color: Colors.white.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: 12),
          Text(
            'No results for "$_searchQuery"',
            style: GoogleFonts.inter(
              color: const Color(0xFF636366),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
