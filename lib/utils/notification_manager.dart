import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/notification_model.dart';

class NotificationManager {
  NotificationManager._();
  static final NotificationManager instance = NotificationManager._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Persistent audio player — must be kept at class level so it is NOT
  /// garbage-collected before the sound finishes playing.
  final AudioPlayer _soundPlayer = AudioPlayer();
  
  /// Reactive notifier for the list of notifications shown in the app.
  /// Starts with the original sample notifications.
  final ValueNotifier<List<NotificationModel>> notificationsNotifier = ValueNotifier<List<NotificationModel>>([
    const NotificationModel(
      id: 'n1',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'A',
      avatarColor: Color(0xFF4A90E2),
      username: 'alex.creates',
      previewText: 'liked your post',
      timestamp: '52m',
      isRead: false,
    ),
    const NotificationModel(
      id: 'n2',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'S',
      avatarColor: Color(0xFF7B61FF),
      username: 'sara.m',
      previewText: 'started following you',
      timestamp: '1h',
      isRead: false,
    ),
    const NotificationModel(
      id: 'n3',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'J',
      avatarColor: Color(0xFFE24A6A),
      username: 'jordan',
      previewText: 'saved your post',
      timestamp: '3h',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n4',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'M',
      avatarColor: Color(0xFF2ECC71),
      username: 'mia.visual',
      previewText: 'commented: "This is stunning 🔥"',
      timestamp: '5h',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n5',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'R',
      avatarColor: Color(0xFFE67E22),
      username: 'ravi.dev',
      previewText: 'liked your post',
      timestamp: '8h',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n6',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'L',
      avatarColor: Color(0xFF1ABC9C),
      username: 'luna.arts',
      previewText: 'started following you',
      timestamp: '1d',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n7',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'K',
      avatarColor: Color(0xFF9B59B6),
      username: 'kai.shoots',
      previewText: 'shared your post',
      timestamp: '1d',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n8',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'P',
      avatarColor: Color(0xFFE74C3C),
      username: 'priya.lens',
      previewText: 'liked your post',
      timestamp: '2d',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n9',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'T',
      avatarColor: Color(0xFF3498DB),
      username: 'tom.ink',
      previewText: 'commented: "Where was this taken?"',
      timestamp: '3d',
      isRead: true,
    ),
    const NotificationModel(
      id: 'n10',
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'Z',
      avatarColor: Color(0xFFF39C12),
      username: 'zara.film',
      previewText: 'started following you',
      timestamp: '5d',
      isRead: true,
    ),
  ]);

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

    // 4. Start mock push notification loop (triggers every 25 seconds)
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
      avatarAssetPath: 'assets/images/panda.png',
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
  void triggerUserActionNotification({
    required String action, // 'liked', 'shared', 'saved'
    required String postTitle,
    String? author,
  }) async {
    final rand = Random();
    final String id = 'user-${DateTime.now().millisecondsSinceEpoch}';
    
    final displayAuthor = (author != null && author.isNotEmpty) ? author : 'a post';
    
    // Format presentation based on the action
    String body = '';
    String title = '';
    Color avatarColor = Colors.blue;
    String initial = '';

    if (action == 'liked') {
      title = 'Post Liked';
      body = 'You liked $displayAuthor\'s post: "$postTitle"';
      avatarColor = const Color(0xFFE24A6A); // Pinkish red
      initial = 'L';
    } else if (action == 'shared') {
      title = 'Post Shared';
      body = 'You shared $displayAuthor\'s post: "$postTitle"';
      avatarColor = const Color(0xFF7B61FF); // Purple
      initial = 'S';
    } else if (action == 'saved') {
      title = 'Post Saved';
      body = 'You saved $displayAuthor\'s post: "$postTitle"';
      avatarColor = const Color(0xFF2ECC71); // Green
      initial = 'B';
    }

    final newNotif = NotificationModel(
      id: id,
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: initial,
      avatarColor: avatarColor,
      username: 'You',
      previewText: body,
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
      title: title,
      body: body,
    );
  }

  /// Triggers a reminder notification for a vault item.
  void triggerVaultReminderNotification(String title) async {
    final rand = Random();
    final String id = 'vault-${DateTime.now().millisecondsSinceEpoch}';
    final newNotif = NotificationModel(
      id: id,
      avatarAssetPath: 'assets/images/panda.png',
      avatarInitial: 'V',
      avatarColor: const Color(0xFFF39C12),
      username: 'Memoria Vault',
      previewText: 'You added a new memory: "$title". Review it in Self Save.',
      timestamp: 'now',
      isRead: false,
    );

    // Prepend to notifications list
    notificationsNotifier.value = [newNotif, ...notifications];
    
    _playNotificationSound();
    _updateLauncherBadge();
    await showLocalNotification(
      id: rand.nextInt(100000),
      title: 'Memoria Vault Reminder',
      body: 'You added a new memory: "$title"',
    );
  }

  /// Renders a native heads-up overlay notification on the OS level.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
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
