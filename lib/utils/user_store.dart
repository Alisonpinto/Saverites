import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

/// Manages user authentication backed by kvdb.io.
///
/// Users list is stored as a JSON array at [_usersUrl].
/// On registration the new user is appended and written back.
/// On login the list is fetched and matched locally.
class UserStore {
  UserStore._();
  static final UserStore instance = UserStore._();

  static const String _usersUrl =
      'https://kvdb.io/9TUwbJpBbNYmE2GMG2qXbT/users';

  // ── Reactive current-user notifier ────────────────────────────────────────
  final ValueNotifier<MemoriaUser?> currentUserNotifier =
      ValueNotifier<MemoriaUser?>(null);

  MemoriaUser? get currentUser => currentUserNotifier.value;

  // ── Session persistence ───────────────────────────────────────────────────

  /// Loads the saved session from SharedPreferences on app start.
  Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      if (!isLoggedIn) return;

      final name = prefs.getString('user_name') ?? '';
      final email = prefs.getString('user_email') ?? '';
      final userId = prefs.getString('user_id') ?? '';
      final password = prefs.getString('user_password') ?? '';
      final createdAt = prefs.getInt('user_created_at') ?? 0;

      if (userId.isNotEmpty) {
        currentUserNotifier.value = MemoriaUser(
          name: name,
          email: email,
          userId: userId,
          password: password,
          createdAt: createdAt,
        );
      }
    } catch (e) {
      debugPrint('UserStore.loadSession error: $e');
    }
  }

  Future<void> _saveSession(MemoriaUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('user_name', user.name);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_id', user.userId);
    await prefs.setString('user_password', user.password);
    await prefs.setInt('user_created_at', user.createdAt);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    currentUserNotifier.value = null;
  }

  // ── Online user registry ──────────────────────────────────────────────────

  Future<List<MemoriaUser>> _fetchAllUsers() async {
    try {
      final resp =
          await http.get(Uri.parse(_usersUrl)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 && resp.body.trim().isNotEmpty) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .map(MemoriaUser.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('UserStore._fetchAllUsers error: $e');
    }
    return [];
  }

  Future<bool> _writeAllUsers(List<MemoriaUser> users) async {
    try {
      final resp = await http
          .put(
            Uri.parse(_usersUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(users.map((u) => u.toJson()).toList()),
          )
          .timeout(const Duration(seconds: 10));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('UserStore._writeAllUsers error: $e');
      return false;
    }
  }

  // ── Uniqueness check ──────────────────────────────────────────────────────

  /// Returns true if [userId] is NOT already taken.
  Future<bool> isUserIdAvailable(String userId) async {
    final users = await _fetchAllUsers();
    return !users.any(
        (u) => u.userId.toLowerCase() == userId.trim().toLowerCase());
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
    if (email.trim().isEmpty || !email.contains('@')) {
      return const AuthResult(success: false, error: 'Enter a valid email address.');
    }
    if (userId.trim().isEmpty || userId.trim().length < 3) {
      return const AuthResult(success: false, error: 'User ID must be at least 3 characters.');
    }
    if (password.length < 6) {
      return const AuthResult(success: false, error: 'Password must be at least 6 characters.');
    }

    // Check uniqueness online
    final users = await _fetchAllUsers();
    final taken = users.any(
        (u) => u.userId.toLowerCase() == userId.trim().toLowerCase());
    if (taken) {
      return const AuthResult(
          success: false,
          error: 'User ID already exists. Please choose a different one.');
    }

    // Also check email uniqueness
    final emailTaken = users.any(
        (u) => u.email.toLowerCase() == email.trim().toLowerCase());
    if (emailTaken) {
      return const AuthResult(
          success: false,
          error: 'An account with that email already exists.');
    }

    final newUser = MemoriaUser(
      name: name.trim(),
      email: email.trim().toLowerCase(),
      userId: userId.trim().toLowerCase(),
      password: password,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    users.add(newUser);
    final saved = await _writeAllUsers(users);
    // Even if the write fails (no network), let the user in locally
    if (!saved) {
      debugPrint('UserStore.register: could not write to kvdb, proceeding locally.');
    }

    await _saveSession(newUser);
    currentUserNotifier.value = newUser;
    return AuthResult(success: true, user: newUser);
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
      await _saveSession(adminUser);
      currentUserNotifier.value = adminUser;
      return AuthResult(success: true, user: adminUser);
    }

    final users = await _fetchAllUsers();
    final query = emailOrUserId.trim().toLowerCase();
    MemoriaUser? match;
    try {
      match = users.firstWhere(
        (u) =>
            (u.email.toLowerCase() == query ||
                u.userId.toLowerCase() == query) &&
            u.password == password,
      );
    } catch (_) {
      match = null;
    }

    if (match == null) {
      return const AuthResult(
          success: false, error: 'Invalid credentials. Please try again.');
    }

    await _saveSession(match);
    currentUserNotifier.value = match;
    return AuthResult(success: true, user: match);
  }
}
