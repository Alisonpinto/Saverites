import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/dice_avatar.dart';

/// Represents a registered Memoria user.
class MemoriaUser {
  final String name;
  final String email;
  final String userId;
  final String password; // stored as plain text (no real backend)
  final int createdAt;

  const MemoriaUser({
    required this.name,
    required this.email,
    required this.userId,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'userId': userId,
        'password': password,
        'createdAt': createdAt,
      };

  factory MemoriaUser.fromJson(Map<String, dynamic> json) => MemoriaUser(
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        password: json['password'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
      );
}

/// Result returned by register / login operations.
class AuthResult {
  final bool success;
  final String? error;
  final MemoriaUser? user;

  const AuthResult({required this.success, this.error, this.user});
}

/// Manages user authentication backed by Supabase.
class UserStore {
  UserStore._();
  static final UserStore instance = UserStore._();

  // ── Reactive current-user notifier ────────────────────────────────────────
  final ValueNotifier<MemoriaUser?> currentUserNotifier =
      ValueNotifier<MemoriaUser?>(null);

  MemoriaUser? get currentUser => currentUserNotifier.value;

  /// Returns a message explaining the ban if the user is banned, or null if not.
  Future<String?> checkBanStatus(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select('body')
          .eq('type', 'ban')
          .eq('title', userId)
          .maybeSingle();

      if (response != null) {
        final expiryStr = response['body'] as String?;
        if (expiryStr != null) {
          if (expiryStr == 'permanent') {
            return 'This account is permanently banned by the administrator.';
          } else {
            final expiry = DateTime.tryParse(expiryStr);
            if (expiry != null && expiry.isAfter(DateTime.now())) {
              return 'This account is banned until ${expiry.toLocal()}.';
            }
          }
        }
      }
    } catch (e) {
      debugPrint('UserStore.checkBanStatus error: $e');
    }
    return null;
  }

  // ── Session persistence ───────────────────────────────────────────────────

  /// Loads the saved session from Supabase / SharedPreferences on app start.
  Future<void> loadSession() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        final userProfile = await _getProfile(session.user.id);
        if (userProfile != null) {
          // Check ban status
          final banMsg = await checkBanStatus(userProfile.userId);
          if (banMsg != null) {
            debugPrint('User is banned: $banMsg. Logging out...');
            await logout();
            return;
          }

          currentUserNotifier.value = userProfile;
          
          // Let's also restore user's avatar seed in local preferences and DiceAvatar state
          final data = await Supabase.instance.client
              .from('profiles')
              .select('avatar_seed')
              .eq('id', session.user.id)
              .maybeSingle();
          if (data != null && data['avatar_seed'] != null) {
            final seed = data['avatar_seed'] as String;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('dice_bear_seed', seed);
            await prefs.setBool('avatar_setup_done', true);
            DiceAvatar.seedNotifier.value = seed;
          }
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
        }
      }
    } catch (e) {
      debugPrint('UserStore.loadSession error: $e');
    }
  }

  Future<void> logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('UserStore.logout error: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.setBool('avatar_setup_done', false);
    await prefs.remove('dice_bear_seed');
    currentUserNotifier.value = null;
  }

  // ── Profile helper ────────────────────────────────────────────────────────

  Future<MemoriaUser?> _getProfile(String authUserId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', authUserId)
          .maybeSingle();
      if (data != null) {
        return MemoriaUser(
          name: data['name'] as String? ?? '',
          email: data['email'] as String? ?? '',
          userId: data['user_id'] as String? ?? '',
          password: '',
          createdAt: data['created_at'] != null 
              ? DateTime.parse(data['created_at'] as String).millisecondsSinceEpoch 
              : 0,
        );
      }
    } catch (e) {
      debugPrint('UserStore._getProfile error: $e');
    }
    return null;
  }

  // ── Uniqueness check ──────────────────────────────────────────────────────

  /// Returns true if [userId] is NOT already taken.
  Future<bool> isUserIdAvailable(String userId) async {
    try {
      final existingUser = await Supabase.instance.client
          .from('profiles')
          .select('user_id')
          .eq('user_id', userId.trim().toLowerCase())
          .maybeSingle();
      return existingUser == null;
    } catch (e) {
      debugPrint('UserStore.isUserIdAvailable error: $e');
      rethrow;
    }
  }

  // ── Random ID generation ──────────────────────────────────────────────────

  static String generateRandomUserId() {
    final prefixes = [
      'saverites',
    ];
    final rng = Random();
    final prefix = prefixes[rng.nextInt(prefixes.length)];
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final suffix = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return '${prefix}_$suffix';
  }

  // ── Registration ──────────────────────────────────────────────────────────

  Future<AuthResult> register({
    required String name,
    required String email,
    required String userId,
    required String password,
  }) async {
    // Basic local validation
    if (name.trim().isEmpty) return const AuthResult(success: false, error: 'Name is required.');
    if (RegExp(r'[0-9]').hasMatch(name)) {
      return const AuthResult(success: false, error: 'Name should not contain numbers.');
    }
    // Block typical special characters except dots/hyphens for initials/hyphenated names
    if (RegExp(r'[!@#\$%^&*()_+=\[{\]};:"<>|/?~`,]').hasMatch(name)) {
      return const AuthResult(success: false, error: 'Name should not contain special characters.');
    }
    if (email.trim().isEmpty || !email.contains('@')) {
      return const AuthResult(success: false, error: 'Enter a valid email address.');
    }
    if (userId.trim().isEmpty || userId.trim().length < 3) {
      return const AuthResult(success: false, error: 'User ID must be at least 3 characters.');
    }
    if (password.length < 6) {
      return const AuthResult(success: false, error: 'Password must be at least 6 characters.');
    }

    try {
      // 1. Check uniqueness of userId in the profiles table
      final available = await isUserIdAvailable(userId);
      if (!available) {
        return const AuthResult(
            success: false,
            error: 'User ID already exists. Please choose a different one.');
      }

      // 2. SignUp via Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return const AuthResult(
            success: false, error: 'Sign up failed. Please try again.');
      }

      // 3. Create profile entry
      final newProfile = {
        'id': user.id,
        'user_id': userId.trim().toLowerCase(),
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
      };
      await Supabase.instance.client.from('profiles').insert(newProfile);

      final newUser = MemoriaUser(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        userId: userId.trim().toLowerCase(),
        password: '',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      currentUserNotifier.value = newUser;
      return AuthResult(success: true, user: newUser);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Registration error: $e');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<AuthResult> login({
    required String emailOrUserId,
    required String password,
  }) async {
    // Legacy admin backdoor
    if (emailOrUserId == 'admin' && password == 'admin') {
      final adminUser = MemoriaUser(
        name: 'Admin',
        email: 'admin@memoria.app',
        userId: 'admin',
        password: 'admin',
        createdAt: 0,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      currentUserNotifier.value = adminUser;
      return AuthResult(success: true, user: adminUser);
    }

    try {
      String resolvedEmail = emailOrUserId.trim().toLowerCase();
      // If the query is not an email, lookup email by user_id
      if (!resolvedEmail.contains('@')) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('email')
            .eq('user_id', resolvedEmail)
            .maybeSingle();
        if (profile == null) {
          return const AuthResult(
              success: false, error: 'Invalid credentials. User ID not found.');
        }
        resolvedEmail = profile['email'] as String;
      }

      // Login via Supabase Auth
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: resolvedEmail,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) {
        return const AuthResult(success: false, error: 'Login failed.');
      }

      // Fetch profile
      final memoriaUser = await _getProfile(user.id);
      if (memoriaUser == null) {
        return const AuthResult(
            success: false, error: 'Login succeeded, but profile details not found.');
      }

      // Check ban status
      final banMsg = await checkBanStatus(memoriaUser.userId);
      if (banMsg != null) {
        await Supabase.instance.client.auth.signOut();
        return AuthResult(success: false, error: banMsg);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Check if user has an avatar seed saved
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_seed')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && data['avatar_seed'] != null) {
        final seed = data['avatar_seed'] as String;
        await prefs.setString('dice_bear_seed', seed);
        await prefs.setBool('avatar_setup_done', true);
        DiceAvatar.seedNotifier.value = seed;
      }

      currentUserNotifier.value = memoriaUser;
      return AuthResult(success: true, user: memoriaUser);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Login error: $e');
    }
  }

  Future<AuthResult> deleteAccount() async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final currentMemoriaUser = this.currentUser;
      if (currentUser == null || currentMemoriaUser == null) {
        return const AuthResult(success: false, error: 'No user logged in.');
      }

      // 1. Delete user files from Supabase Storage first
      try {
        final posts = await Supabase.instance.client
            .from('posts')
            .select('image_url, video_url, file_url, file_urls')
            .eq('user_id', currentMemoriaUser.userId);

        final List<String> filesToDelete = [];
        for (var p in posts) {
          final imageUrl = p['image_url'] as String?;
          final videoUrl = p['video_url'] as String?;
          final fileUrl = p['file_url'] as String?;
          final fileUrls = (p['file_urls'] as List?)?.cast<String>();

          if (imageUrl != null) _extractPathAndAdd(imageUrl, filesToDelete);
          if (videoUrl != null) _extractPathAndAdd(videoUrl, filesToDelete);
          if (fileUrl != null) _extractPathAndAdd(fileUrl, filesToDelete);
          if (fileUrls != null) {
            for (var url in fileUrls) {
              _extractPathAndAdd(url, filesToDelete);
            }
          }
        }

        if (filesToDelete.isNotEmpty) {
          await Supabase.instance.client.storage
              .from('post-media')
              .remove(filesToDelete);
        }
      } catch (e) {
        debugPrint('Error clearing user storage files: $e');
      }

      // 2. Call the secure RPC function to delete the auth user
      await Supabase.instance.client.rpc('delete_user');

      // 3. Clear local session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false);
      await prefs.setBool('avatar_setup_done', false);
      await prefs.remove('dice_bear_seed');
      currentUserNotifier.value = null;

      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Account deletion error: $e');
    }
  }

  // ── Update User ID ────────────────────────────────────────────────────────

  /// Lets the signed-in user change their unique user ID.
  /// Returns an [AuthResult] with success/error info.
  Future<AuthResult> updateUserId(String newUserId) async {
    final trimmed = newUserId.trim().toLowerCase();

    if (trimmed.isEmpty || trimmed.length < 3) {
      return const AuthResult(success: false, error: 'User ID must be at least 3 characters.');
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(trimmed)) {
      return const AuthResult(
          success: false, error: 'Only lowercase letters, numbers, and underscores are allowed.');
    }

    try {
      final currentAuth = Supabase.instance.client.auth.currentUser;
      if (currentAuth == null) {
        return const AuthResult(success: false, error: 'Not signed in.');
      }

      // 1. Check uniqueness
      final available = await isUserIdAvailable(trimmed);
      if (!available) {
        return const AuthResult(
            success: false, error: 'User ID is already taken. Choose a different one.');
      }

      // 2. Update in Supabase profiles table
      await Supabase.instance.client
          .from('profiles')
          .update({'user_id': trimmed})
          .eq('id', currentAuth.id);

      // 3. Update local state so UI reflects immediately
      final old = currentUserNotifier.value;
      if (old != null) {
        currentUserNotifier.value = MemoriaUser(
          name: old.name,
          email: old.email,
          userId: trimmed,
          password: old.password,
          createdAt: old.createdAt,
        );
      }

      return const AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Update error: $e');
    }
  }

  void _extractPathAndAdd(String publicUrl, List<String> list) {
    try {
      final uri = Uri.parse(publicUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.length > 5) {
        final filePath = pathSegments.sublist(5).join('/');
        list.add(filePath);
      }
    } catch (_) {}
  }

  // ── Google Sign In ────────────────────────────────────────────────────────
  
  Future<AuthResult> loginWithGoogle({
    required String idToken,
    required String accessToken,
  }) async {
    try {
      final authResponse = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = authResponse.user;
      if (user == null) {
        return const AuthResult(success: false, error: 'Google sign in failed.');
      }

      // Check if profile exists; if not, create a default profile for the user
      var memoriaUser = await _getProfile(user.id);
      if (memoriaUser == null) {
        final metadata = user.userMetadata ?? {};
        final fullName = metadata['full_name'] as String? ?? metadata['name'] as String? ?? 'Google User';
        final email = user.email ?? '';
        
        // Generate a random username or extract it from email
        String generatedUserId = email.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (generatedUserId.length < 3) {
          generatedUserId = generateRandomUserId();
        }
        
        // Check uniqueness of generatedUserId
        bool available = await isUserIdAvailable(generatedUserId);
        int suffix = 1;
        final baseId = generatedUserId;
        while (!available) {
          generatedUserId = '${baseId}_$suffix';
          available = await isUserIdAvailable(generatedUserId);
          suffix++;
        }

        final newProfile = {
          'id': user.id,
          'user_id': generatedUserId,
          'name': fullName,
          'email': email,
        };
        await Supabase.instance.client.from('profiles').insert(newProfile);

        memoriaUser = MemoriaUser(
          name: fullName,
          email: email,
          userId: generatedUserId,
          password: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      // Check ban status
      final banMsg = await checkBanStatus(memoriaUser.userId);
      if (banMsg != null) {
        await Supabase.instance.client.auth.signOut();
        return AuthResult(success: false, error: banMsg);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Check if user has an avatar seed saved
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_seed')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && data['avatar_seed'] != null) {
        final seed = data['avatar_seed'] as String;
        await prefs.setString('dice_bear_seed', seed);
        await prefs.setBool('avatar_setup_done', true);
        DiceAvatar.seedNotifier.value = seed;
      }

      currentUserNotifier.value = memoriaUser;
      return AuthResult(success: true, user: memoriaUser);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Google sign in error: $e');
    }
  }

  Future<AuthResult> handleOAuthSession(Session session, {bool isRegisterMode = false}) async {
    try {
      final user = session.user;
      
      // Fetch profile to check if account already exists
      var memoriaUser = await _getProfile(user.id);

      // ── Key check: If user is trying to REGISTER but already has an account ──
      if (isRegisterMode && memoriaUser != null) {
        // Profile exists — they're already registered. Sign them out of this
        // OAuth session and tell them to use the Log In tab instead.
        await Supabase.instance.client.auth.signOut();
        return const AuthResult(
          success: false,
          error: 'An account with this Google email already exists. Please use "Log In" instead.',
        );
      }

      if (memoriaUser == null) {
        final metadata = user.userMetadata ?? {};
        final fullName = metadata['full_name'] as String? ?? metadata['name'] as String? ?? 'Google User';
        final email = user.email ?? '';
        
        // Generate a unique username from the email prefix
        String generatedUserId = email.split('@').first.replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (generatedUserId.length < 3) {
          generatedUserId = generateRandomUserId();
        }
        
        // Ensure uniqueness
        bool available = await isUserIdAvailable(generatedUserId);
        int suffix = 1;
        final baseId = generatedUserId;
        while (!available) {
          generatedUserId = '${baseId}_$suffix';
          available = await isUserIdAvailable(generatedUserId);
          suffix++;
        }

        final newProfile = {
          'id': user.id,
          'user_id': generatedUserId,
          'name': fullName,
          'email': email,
        };
        await Supabase.instance.client.from('profiles').insert(newProfile);

        memoriaUser = MemoriaUser(
          name: fullName,
          email: email,
          userId: generatedUserId,
          password: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      // Check ban status
      final banMsg = await checkBanStatus(memoriaUser.userId);
      if (banMsg != null) {
        await Supabase.instance.client.auth.signOut();
        return AuthResult(success: false, error: banMsg);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      // Restore avatar seed if saved
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_seed')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && data['avatar_seed'] != null) {
        final seed = data['avatar_seed'] as String;
        await prefs.setString('dice_bear_seed', seed);
        await prefs.setBool('avatar_setup_done', true);
        DiceAvatar.seedNotifier.value = seed;
      }

      currentUserNotifier.value = memoriaUser;
      return AuthResult(success: true, user: memoriaUser);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: e.message);
    } catch (e) {
      return AuthResult(success: false, error: 'Google sign in session handle error: $e');
    }
  }

  Future<void> signInWithGoogleOAuth() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'saverites://login-callback',
    );
  }
}
