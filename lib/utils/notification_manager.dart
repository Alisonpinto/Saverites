import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../widgets/dice_avatar.dart';
import '../widgets/in_app_notification.dart';
import 'post_store.dart';
import 'user_store.dart';

class NotificationManager {
  NotificationManager._();
  static final NotificationManager instance = NotificationManager._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Persistent audio player — must be kept at class level so it is NOT
  /// garbage-collected before the sound finishes playing.
  final AudioPlayer _soundPlayer = AudioPlayer();
  
  /// Reactive notifier for the list of notifications shown in the app.
  /// Starts with empty list.
  final ValueNotifier<List<NotificationModel>> notificationsNotifier =
      ValueNotifier<List<NotificationModel>>([]);

  List<NotificationModel> get notifications => notificationsNotifier.value;
  
  /// Current unread count
  int get unreadCount => notifications.where((n) => !n.isRead).length;

  Timer? _simulationTimer;

  /// Initialize local notification plugins and set the initial launcher icon badge count.
  Future<void> init() async {
    // 1. Configure local notifications settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );
    
    try {
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Notification clicked: ${response.payload}");
        },
      );
      
      // Request notification permissions for Android 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint("Error initializing local notifications: $e");
    }

    // 2. Configure the audio player once
    try {
      await _soundPlayer.setVolume(1.0);
      // Use RING audio stream on Android so it plays at full volume
      await _soundPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
    } catch (e) {
      debugPrint("Error setting up audio player: $e");
    }

    // 3. Set the initial launcher badge count
    _updateLauncherBadge();

    // 4. Start periodic reminder check timer (runs every 10 seconds)
    // _startReminderTimer();

    // 5. Start mock push notification loop (triggers every 25 seconds)
    // startSimulation();
  }

  /// Periodically simulates incoming actions from "friends"
  void startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _triggerSimulatedNotification();
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
  }

  final List<Map<String, String>> _mockActivities = [
    {'username': 'emma.visuals', 'action': 'liked your post', 'initial': 'E', 'color': '0xFF9B59B6'},
    {'username': 'dan_code', 'action': 'commented: "Clean work! 🚀"', 'initial': 'D', 'color': '0xFF2ECC71'},
    {'username': 'jess.shoots', 'action': 'shared your post', 'initial': 'J', 'color': '0xFFFF1744'},
    {'username': 'zack.fit', 'action': 'started following you', 'initial': 'Z', 'color': '0xFFF1C40F'},
    {'username': 'sara.m', 'action': 'posted a new photo', 'initial': 'S', 'color': '0xFF7B61FF'},
  ];

  void _playNotificationSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;

      // Stop any currently playing sound first to avoid overlap
      await _soundPlayer.stop();
      // Play the bundled asset sound at full volume
      await _soundPlayer.play(AssetSource('audio/notification_sound.mp3'));
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }
  }

  void _triggerSimulatedNotification() async {
    final rand = Random();
    final activity = _mockActivities[rand.nextInt(_mockActivities.length)];
    final String id = 'sim-${DateTime.now().millisecondsSinceEpoch}';
    
    final newNotif = NotificationModel(
      id: id,
      avatarSeed: activity['username'], // use username as DiceBear seed
      avatarInitial: activity['initial']!,
      avatarColor: Color(int.parse(activity['color']!)),
      username: activity['username']!,
      previewText: activity['action']!,
      timestamp: 'now',
      isRead: false,
    );

    // Prepend to notifications list
    notificationsNotifier.value = [newNotif, ...notifications];
    
    _playNotificationSound();
    
    // Update dynamic badge indicators
    _updateLauncherBadge();

    // Show OS level local notification
    await showLocalNotification(
      id: rand.nextInt(100000),
      title: activity['username']!,
      body: activity['action']!,
    );
  }

  /// Triggers a notification for a user action (like, share, save).
  ///
  /// Pass [isIncoming] = true when triggered by a remote user (e.g. someone else
  /// liked YOUR post). When [isIncoming] is true, [remoteUsername], [remoteAvatarColor]
  /// and [remoteAvatarInitial] describe the person who performed the action.
  void triggerUserActionNotification({
    required String action, // 'liked', 'shared', 'saved'
    required String postTitle,
    String? author,
    bool isIncoming = false,
    String? remoteUsername,
    Color? remoteAvatarColor,
    String? remoteAvatarInitial,
    String? remoteAvatarAssetPath,
  }) async {
    final rand = Random();
    final String id = 'user-${DateTime.now().millisecondsSinceEpoch}';

    // The person who performed the action
    final actorName = isIncoming
        ? (remoteUsername ?? 'Someone')
        : (author != null && author.isNotEmpty ? author : 'Someone');

    // Format body text based on action and direction
    String body = '';
    String title = '';
    Color avatarColor;
    String initial;
    String? avatarAsset;

    if (isIncoming) {
      // Remote user liked / shared our post
      avatarColor = remoteAvatarColor ?? const Color(0xFFE24A6A);
      initial = remoteAvatarInitial ?? actorName[0].toUpperCase();
      avatarAsset = remoteAvatarAssetPath;
      if (action == 'liked') {
        title = 'Someone liked your post';
        body = '$actorName liked your post: "$postTitle"';
      } else if (action == 'shared') {
        title = 'Someone shared your post';
        body = '$actorName shared your post: "$postTitle"';
      } else {
        title = 'Post activity';
        body = '$actorName interacted with "$postTitle"';
      }
    } else {
      // Local user performed an action
      avatarColor = action == 'liked'
          ? const Color(0xFFE24A6A)
          : action == 'shared'
              ? const Color(0xFF7B61FF)
              : const Color(0xFF2ECC71);
      initial = action == 'liked' ? 'L' : action == 'shared' ? 'S' : 'B';
      avatarAsset = null;

      if (action == 'liked') {
        title = 'Post Liked';
        body = 'You liked $actorName\'s post: "$postTitle"';
      } else if (action == 'shared') {
        title = 'Post Shared';
        body = 'You shared $actorName\'s post: "$postTitle"';
      } else if (action == 'saved') {
        title = 'Post Saved';
        body = 'You saved $actorName\'s post: "$postTitle"';
      }
    }

    final String currentUserId = UserStore.instance.currentUser?.userId ?? 'You';

    final newNotif = NotificationModel(
      id: id,
      // For own actions use the user's dice avatar seed; for remote actors use their username as seed
      avatarSeed: isIncoming ? actorName : DiceAvatar.seedNotifier.value,
      avatarInitial: initial,
      avatarColor: avatarColor,
      username: isIncoming ? actorName : currentUserId,
      previewText: isIncoming
          ? body
          : (action == 'liked'
              ? 'liked $actorName\'s post: "$postTitle"'
              : action == 'shared'
                  ? 'shared $actorName\'s post: "$postTitle"'
                  : 'saved $actorName\'s post: "$postTitle"'),
      timestamp: 'now',
      isRead: false,
    );

    // Prepend to notifications list
    notificationsNotifier.value = [newNotif, ...notifications];

    // Always trigger sound, badge, and native heads-up OS notification for all actions.
    _playNotificationSound();
    _updateLauncherBadge();

    await showLocalNotification(
      id: rand.nextInt(100000),
      title: title,
      body: body,
    );

    // Suppress custom in-app banners for local actions (so they don't cover the screen 'in between the app').
    // Only show the custom in-app banner for incoming remote actions.
    if (isIncoming) {
      InAppNotificationHelper.show(
        body: body,
        showMedia: false,
        avatarInitial: initial,
        avatarColor: avatarColor,
        avatarAssetPath: avatarAsset,
      );
    }
  }

  /// Triggers a reminder notification for a vault item.
  void triggerVaultReminderNotification(String title) async {
    final String id = 'vault-${DateTime.now().millisecondsSinceEpoch}';
    const Color vaultColor = Color(0xFFF39C12);
    const String vaultInitial = 'V';
    final String body = 'You added a new memory: "$title". Review it in Self Save.';

    final newNotif = NotificationModel(
      id: id,
      avatarSeed: 'memoria_vault', // consistent vault avatar seed
      avatarInitial: vaultInitial,
      avatarColor: vaultColor,
      username: 'Memoria Vault',
      previewText: body,
      timestamp: 'now',
      isRead: false,
    );

    // Prepend to notifications list
    notificationsNotifier.value = [newNotif, ...notifications];

    _playNotificationSound();
    _updateLauncherBadge();

    await showLocalNotification(
      id: Random().nextInt(100000),
      title: 'Memoria Vault Reminder',
      body: 'You added a new memory: "$title"',
    );

    // In-app banner is commented out to avoid popping up inside the app UI.
    // InAppNotificationHelper.show(
    //   body: body,
    //   showMedia: false,
    //   avatarInitial: vaultInitial,
    //   avatarColor: vaultColor,
    //   avatarAssetPath: 'assets/images/panda.png',
    // );
  }

  /// Renders a native heads-up overlay notification on the OS level.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;
    } catch (e) {
      debugPrint("Error reading notification setting: $e");
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'memoria_notifications_silent',
      'Memoria Notifications',
      channelDescription: 'Notifications for likes, comments, and posts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: false, // Disable system default sound
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // Disable system default sound
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: 'notification_screen',
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  /// Marks all current notifications as read and resets badge counts.
  void markAllAsRead() {
    notificationsNotifier.value = notifications.map((n) {
      return NotificationModel(
        id: n.id,
        avatarAssetPath: n.avatarAssetPath,
        avatarSeed: n.avatarSeed,
        avatarInitial: n.avatarInitial,
        avatarColor: n.avatarColor,
        username: n.username,
        previewText: n.previewText,
        timestamp: n.timestamp,
        isRead: true,
      );
    }).toList();

    _updateLauncherBadge();
  }



  Future<void> triggerSavedItemsCheck() async {
    await checkAndTriggerSavedItemsReminder();
  }

  Future<void> checkAndTriggerSavedItemsReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;

      final interval = prefs.getString('savedItemsReminderInterval') ?? 'Always';
      if (interval == 'Never') return;

      // Check if there are any saved items
      final savedPredefinedCount = PostStore.instance.savedSocialPostIds.length;
      final savedUserPosts = PostStore.instance.posts.where((p) => p.savedInProfile).toList();
      final totalSaved = savedPredefinedCount + savedUserPosts.length;

      if (totalSaved == 0) return;

      // Get the last reminder timestamp
      final lastReminderMs = prefs.getInt('lastSavedItemsReminderTimestamp') ?? 0;
      final lastReminder = DateTime.fromMillisecondsSinceEpoch(lastReminderMs);
      final now = DateTime.now();

      Duration checkDuration;
      if (interval == 'Always') {
        checkDuration = const Duration(seconds: 45); // periodic checking for testing
      } else if (interval == '2 Days') {
        checkDuration = const Duration(days: 2);
      } else if (interval == '1 Week') {
        checkDuration = const Duration(days: 7);
      } else if (interval == '1 Month') {
        checkDuration = const Duration(days: 30);
      } else {
        return;
      }

      if (now.difference(lastReminder) >= checkDuration) {
        // Record the timestamp
        await prefs.setInt('lastSavedItemsReminderTimestamp', now.millisecondsSinceEpoch);

        // Pick a random saved item title if available
        String title = "your saved items";
        String? localImagePath;
        String? assetImagePath;

        if (savedUserPosts.isNotEmpty && (savedPredefinedCount == 0 || Random().nextBool())) {
          final rand = Random();
          final post = savedUserPosts[rand.nextInt(savedUserPosts.length)];
          title = '"${post.title}"';
          localImagePath = post.imagePath;
        } else if (PostStore.instance.savedSocialPostIds.isNotEmpty) {
          final socialSaves = PostStore.predefinedPosts
              .where((p) => PostStore.instance.savedSocialPostIds.contains(p.id))
              .toList();
          if (socialSaves.isNotEmpty) {
            final rand = Random();
            final post = socialSaves[rand.nextInt(socialSaves.length)];
            title = '"${post.title ?? 'Untitled'}"';
            assetImagePath = post.mediaAssetPath;
          }
        }

        final body = 'Remember to review your saved item: $title';
        final String notifId = 'reminder-${now.millisecondsSinceEpoch}';
        
        final newNotif = NotificationModel(
          id: notifId,
          avatarSeed: 'memoria_reminder', // consistent reminder avatar seed
          avatarInitial: 'R',
          avatarColor: const Color(0xFFFF9500),
          username: 'Memoria Reminder',
          previewText: body,
          timestamp: 'now',
          isRead: false,
        );

        // Prepend to notifications list
        notificationsNotifier.value = [newNotif, ...notifications];
        
        _playNotificationSound();
        _updateLauncherBadge();

        await showLocalNotification(
          id: Random().nextInt(100000),
          title: 'Saved Items Reminder',
          body: body,
        );

        await InAppNotificationHelper.show(
          body: body,
          imagePath: localImagePath,
          assetImagePath: assetImagePath,
          showMedia: localImagePath != null || assetImagePath != null,
          avatarInitial: 'R',
          avatarColor: const Color(0xFFFF9500),
          avatarAssetPath: 'assets/images/panda.png',
        );
      }
    } catch (e) {
      debugPrint("Error running saved items reminder check: $e");
    }
  }

  void _updateLauncherBadge() async {
    try {
      if (await AppBadgePlus.isSupported()) {
        await AppBadgePlus.updateBadge(unreadCount);
      }
    } catch (e) {
      debugPrint("Error updating launcher badge: $e");
    }
  }
}
