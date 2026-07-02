import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/dice_avatar.dart';
import '../../utils/user_store.dart';

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = "";
  bool _permissionDenied = false;
  bool _isLoadingContacts = false;
  List<Contact> _contacts = [];
  List<Map<String, dynamic>> _supabaseProfiles = [];
  bool _isLoadingProfiles = true;
  final Set<String> _followingUserIds = {};
  final Set<String> _requestedUserIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfiles();
    _fetchContacts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final client = Supabase.instance.client;
      final currentUserUuid = client.auth.currentUser?.id;

      final response = await client.from('profiles').select();
      
      final profiles = List<Map<String, dynamic>>.from(response)
          .where((p) => p['id'] != currentUserUuid)
          .toList();

      final List<String> follows = [];
      final List<String> requests = [];

      final currentUserId = UserStore.instance.currentUser?.userId ?? '';
      if (currentUserUuid != null) {
        // Query follows
        final followsRes = await client
            .from('user_follows')
            .select('followed_id')
            .eq('follower_id', currentUserUuid);
        follows.addAll(List<String>.from(followsRes.map((r) => r['followed_id'].toString())));

        // Query pending requests
        final reqsRes = await client
            .from('notifications')
            .select('to_user_id')
            .eq('from_user_id', currentUserId)
            .eq('action_type', 'friend_request');
        requests.addAll(List<String>.from(reqsRes.map((r) => r['to_user_id'].toString())));
      }

      if (mounted) {
        setState(() {
          _supabaseProfiles = profiles;
          _followingUserIds.clear();
          _followingUserIds.addAll(follows);
          _requestedUserIds.clear();
          _requestedUserIds.addAll(requests);
          _isLoadingProfiles = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching Supabase profiles: $e");
      if (mounted) {
        setState(() {
          _supabaseProfiles = [
            {'id': 'design_curator', 'name': 'Alex Rivera', 'user_id': 'design_curator', 'username': 'design_curator', 'avatar_seed': 'curator', 'email': 'alex@example.com'},
            {'id': 'pixel_perfect', 'name': 'Jessica Chen', 'user_id': 'pixel_perfect', 'username': 'pixel_perfect', 'avatar_seed': 'pixel', 'email': 'jess@example.com'},
            {'id': 'nomad_adventurer', 'name': 'Marcus Aurelius', 'user_id': 'nomad_adventurer', 'username': 'nomad_adventurer', 'avatar_seed': 'nomad', 'email': 'marcus@example.com'},
            {'id': 'aesthetic_vibes', 'name': 'Sophia Loren', 'user_id': 'aesthetic_vibes', 'username': 'aesthetic_vibes', 'avatar_seed': 'vibes', 'email': 'sophia@example.com'},
          ];
          _isLoadingProfiles = false;
        });
      }
    }
  }

  Future<void> _toggleFollowOrRequest(String targetUuid, String targetUsername) async {
    final client = Supabase.instance.client;
    final currentUserUuid = client.auth.currentUser?.id;
    final currentUserId = UserStore.instance.currentUser?.userId ?? 'Someone';

    if (currentUserUuid == null) return;

    final isFollowing = _followingUserIds.contains(targetUuid);
    final isRequested = _requestedUserIds.contains(targetUsername);

    setState(() {
      if (isFollowing) {
        _followingUserIds.remove(targetUuid);
      } else if (isRequested) {
        _requestedUserIds.remove(targetUsername);
      } else {
        _requestedUserIds.add(targetUsername);
      }
    });

    try {
      if (isFollowing) {
        await client
            .from('user_follows')
            .delete()
            .eq('follower_id', currentUserUuid)
            .eq('followed_id', targetUuid);
      } else if (isRequested) {
        await client
            .from('notifications')
            .delete()
            .eq('from_user_id', currentUserId)
            .eq('to_user_id', targetUsername)
            .eq('action_type', 'friend_request');
      } else {
        final String notifId = 'freq-${DateTime.now().millisecondsSinceEpoch}';
        await client.from('notifications').insert({
          'id': notifId,
          'to_user_id': targetUsername,
          'from_user_id': currentUserId,
          'avatar_seed': currentUserId,
          'avatar_initial': currentUserId.isNotEmpty ? currentUserId[0].toUpperCase() : 'U',
          'avatar_color': const Color(0xFF6B9BF7).toARGB32(),
          'username': currentUserId,
          'preview_text': 'sent you a friend request',
          'action_type': 'friend_request',
          'is_read': false,
        });
      }
      _loadProfiles();
    } catch (e) {
      debugPrint("Error toggling follow/request: $e");
      _loadProfiles();
    }
  }

  Future<void> _fetchContacts() async {
    if (mounted) setState(() => _isLoadingContacts = true);
    try {
      final hasPermission = await FlutterContacts.permissions.has(PermissionType.read);
      if (!hasPermission) {
        final status = await FlutterContacts.permissions.request(PermissionType.read);
        if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
          if (mounted) {
            setState(() {
              _permissionDenied = true;
              _isLoadingContacts = false;
            });
          }
          return;
        }
      }

      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone, ContactProperty.email});
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _permissionDenied = false;
          _isLoadingContacts = false;
        });
      }
    } catch (e) {
      debugPrint("Contacts not supported on this platform: $e");
      // Populate with high quality mock contacts for non-mobile platforms
      if (mounted) {
        setState(() {
          _permissionDenied = false; // Bypass to show mock list
          _isLoadingContacts = false;
          _contacts = [
            Contact(
              displayName: "Alex Rivera",
              name: const Name(first: "Alex", last: "Rivera"),
              emails: [const Email(address: "alex@example.com")],
              phones: [const Phone(number: "+19876543210")],
            ),
            Contact(
              displayName: "Jessica Chen",
              name: const Name(first: "Jessica", last: "Chen"),
              emails: [const Email(address: "jess@example.com")],
              phones: [const Phone(number: "+19876543211")],
            ),
            Contact(
              displayName: "Pam Beesly",
              name: const Name(first: "Pam", last: "Beesly"),
              phones: [const Phone(number: "+19876543212")],
            ),
            Contact(
              displayName: "Jim Halpert",
              name: const Name(first: "Jim", last: "Halpert"),
              phones: [const Phone(number: "+19876543213")],
            ),
          ];
        });
      }
    }
  }

  Map<String, dynamic>? _getMatchingProfile(Contact contact) {
    // 1. Try email match
    for (var emailObj in contact.emails) {
      final emailStr = emailObj.address.trim().toLowerCase();
      if (emailStr.isNotEmpty) {
        for (var p in _supabaseProfiles) {
          final dbEmail = (p['email'] ?? '').toString().trim().toLowerCase();
          if (dbEmail == emailStr) return p;
        }
      }
    }

    // 2. Fallback: match by name
    final contactName = (contact.displayName ?? '').trim().toLowerCase();
    if (contactName.isNotEmpty) {
      for (var p in _supabaseProfiles) {
        final dbName = (p['name'] ?? '').toString().trim().toLowerCase();
        final dbUsername = (p['user_id'] ?? p['username'] ?? '').toString().trim().toLowerCase();
        if (dbName == contactName || dbUsername == contactName) return p;
      }
    }
    return null;
  }

  void _showInviteSheet(BuildContext context, String contactName, String contactNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        final String inviteText = "Hey! Join me on Saverites to secure and share our favorite moments. Download here: https://saveriteswebsite.vercel.app/download";
        
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Invite $contactName',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose where to send your invitation link',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFAEAEB2),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInviteOption(
                      customIcon: SvgPicture.asset(
                        'assets/images/whatsapp-svgrepo-com.svg',
                        width: 28,
                        height: 28,
                      ),
                      color: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final cleanNumber = contactNumber.replaceAll(RegExp(r'[^\d+]'), '');
                        final encodedText = Uri.encodeComponent(inviteText);
                        final url = "https://wa.me/$cleanNumber?text=$encodedText";
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } else {
                          Share.share(inviteText);
                        }
                      },
                    ),
                    _buildInviteOption(
                      customIcon: SvgPicture.asset(
                        'assets/images/instagram-2-1-logo-svgrepo-com.svg',
                        width: 26,
                        height: 26,
                      ),
                      color: const Color(0xFFE1306C),
                      label: 'Instagram',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final url = "https://instagram.com/";
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } else {
                          Share.share(inviteText);
                        }
                      },
                    ),
                    _buildInviteOption(
                      customIcon: SvgPicture.asset(
                        'assets/images/facebook-icon-logo-svgrepo-com.svg',
                        width: 28,
                        height: 28,
                      ),
                      color: const Color(0xFF1877F2),
                      label: 'Facebook',
                      onTap: () async {
                        Navigator.pop(ctx);
                        final url = "https://facebook.com/";
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        } else {
                          Share.share(inviteText);
                        }
                      },
                    ),
                    _buildInviteOption(
                      icon: Icons.share_rounded,
                      color: Colors.white70,
                      label: 'Share',
                      onTap: () {
                        Navigator.pop(ctx);
                        Share.share(inviteText);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteOption({
    IconData? icon,
    Widget? customIcon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: customIcon ?? Icon(icon, color: color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111216),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        title: Text(
          'Find Friends',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6B9BF7),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFAEAEB2),
          labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Saverites Users'),
            Tab(text: 'Device Contacts'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Sleek Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white),
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFAEAEB2)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFFAEAEB2)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                  hintText: 'Search friends...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFFAEAEB2), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfilesTab(),
                _buildContactsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilesTab() {
    if (_isLoadingProfiles) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6B9BF7)));
    }

    final filtered = _supabaseProfiles.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final username = (p['user_id'] ?? p['username'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || username.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No users found on Saverites.',
          style: GoogleFonts.inter(color: const Color(0xFFAEAEB2), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final profile = filtered[index];
        final id = (profile['id'] ?? '').toString();
        final name = (profile['name'] ?? 'User').toString();
        final username = (profile['user_id'] ?? profile['username'] ?? id).toString();
        final seed = (profile['avatar_seed'] ?? username).toString();
        final isFollowing = _followingUserIds.contains(id);
        final isRequested = _requestedUserIds.contains(username);

        String btnLabel = 'Connect';
        Color btnColor = const Color(0xFFFFF78E);
        Color textColor = Colors.black;
        Color borderColor = const Color(0xFFFFF78E);

        if (isFollowing) {
          btnLabel = 'Connected';
          btnColor = Colors.transparent;
          textColor = const Color(0xFFFFF78E);
          borderColor = const Color(0xFFFFF78E);
        } else if (isRequested) {
          btnLabel = 'Requested';
          btnColor = const Color(0xFF2C2C2E);
          textColor = Colors.white70;
          borderColor = const Color(0xFF2C2C2E);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              DiceAvatar(radius: 22, seed: seed),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFAEAEB2),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleFollowOrRequest(id, username),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: btnColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    btnLabel,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactsTab() {
    if (_isLoadingContacts) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6B9BF7)));
    }

    if (_permissionDenied) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.contacts_rounded, size: 64, color: Color(0xFFAEAEB2)),
            const SizedBox(height: 16),
            Text(
              'Access Device Contacts',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Allow Saverites to scan your contacts to find friends already registered or send invites.',
              style: GoogleFonts.inter(
                color: const Color(0xFFAEAEB2),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchContacts,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B9BF7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Enable Contacts',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _contacts.where((c) {
      final name = (c.displayName ?? '').toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No contacts found.',
          style: GoogleFonts.inter(color: const Color(0xFFAEAEB2), fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final name = contact.displayName ?? 'Unknown';
        final phone = contact.phones.isNotEmpty ? contact.phones.first.number : "";
        
        final matchedProfile = _getMatchingProfile(contact);
        final bool isAlreadyOnSaverites = matchedProfile != null;
        
        final followTargetId = matchedProfile != null ? (matchedProfile['id'] ?? name).toString() : name;
        final targetUsername = matchedProfile != null
            ? (matchedProfile['user_id'] ?? matchedProfile['username'] ?? "").toString()
            : "";
        final isFollowing = _followingUserIds.contains(followTargetId);
        final isRequested = _requestedUserIds.contains(targetUsername);

        String btnLabel = 'Connect';
        Color btnColor = const Color(0xFFFFF78E);
        Color textColor = Colors.black;
        Color borderColor = const Color(0xFFFFF78E);

        if (isFollowing) {
          btnLabel = 'Connected';
          btnColor = Colors.transparent;
          textColor = const Color(0xFFFFF78E);
          borderColor = const Color(0xFFFFF78E);
        } else if (isRequested) {
          btnLabel = 'Requested';
          btnColor = const Color(0xFF2C2C2E);
          textColor = Colors.white70;
          borderColor = const Color(0xFF2C2C2E);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              DiceAvatar(radius: 22, seed: name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone.isNotEmpty ? phone : 'No phone number',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFAEAEB2),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAlreadyOnSaverites)
                GestureDetector(
                  onTap: () => _toggleFollowOrRequest(followTargetId, targetUsername),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: btnColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      btnLabel,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _showInviteSheet(context, name, phone),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Text(
                      'Invite',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
