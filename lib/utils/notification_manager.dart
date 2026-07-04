import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../models/notification_model.dart';
import '../widgets/dice_avatar.dart';
import 'post_store.dart';
import 'user_store.dart';
import '../main.dart';
import '../screens/post_detail/post_detail_screen.dart';
import '../models/post_model.dart';

class NotificationManager {
  NotificationManager._();
  static final NotificationManager instance = NotificationManager._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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
  Timer? _remoteSyncTimer;
  Timer? _savedItemsReminderTimer;
  RealtimeChannel? _realtimeChannel;

  /// Initialize local notification plugins and set the initial launcher icon badge count.
  Future<void> init() async {
    // 1. Configure local notifications settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
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
          final payload = response.payload;
          if (payload != null && payload.startsWith('post:')) {
            final postId = payload.substring(5);
            _handleNotificationNavigation(postId);
          }
        },
      );

      // Request notification permissions for Android 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint("Error initializing local notifications: $e");
    }

    // 2. Configure the audio player once
    try {
      await _soundPlayer.setVolume(1.0);
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

    // 4. Start remote sync timer for fallback sync
    startRemoteSyncTimer();

    // Start saved items reminder timer
    startSavedItemsReminderTimer();

    // 5. Reset and re-subscribe Realtime channel when user logs in/out
    UserStore.instance.currentUserNotifier.addListener(() {
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = null;
      syncOnlineNotifications();
    });
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

  Future<String> _generateIconThumbnail(String type, String title) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 400, 400));

    // Choose colors based on type
    Color bgColor = const Color(0xFF333333);
    String symbol = "📄";

    switch (type) {
      case 'checklist':
        bgColor = const Color(0xFF2ECC71); // Green
        symbol = "📝";
        break;
      case 'audio':
        bgColor = const Color(0xFFE74C3C); // Red
        symbol = "🎙️";
        break;
      case 'document':
        bgColor = const Color(0xFF3498DB); // Blue
        symbol = "📁";
        break;
      case 'contact':
        bgColor = const Color(0xFF9B59B6); // Purple
        symbol = "👤";
        break;
      case 'code':
        bgColor = const Color(0xFF34495E); // Dark Slate
        symbol = "💻";
        break;
      case 'link':
        bgColor = const Color(0xFF1ABC9C); // Teal
        symbol = "🔗";
        break;
      case 'text':
      default:
        bgColor = const Color(0xFFF1C40F); // Yellow/Amber
        symbol = "🧠";
        break;
    }

    // Draw background rounded rectangle
    final paint = Paint()
      ..color = bgColor
      ..style = ui.PaintingStyle.fill;
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 400, 400),
        const Radius.circular(60),
      ),
      paint,
    );

    // Draw symbol (emoji icon) in the center
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: symbol,
      style: const TextStyle(
        fontSize: 150,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((400 - textPainter.width) / 2, (360 - textPainter.height) / 2),
    );

    // Draw a small title text at the bottom
    final titlePainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    titlePainter.text = TextSpan(
      text: title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 26,
        fontWeight: FontWeight.bold,
      ),
    );
    titlePainter.layout(maxWidth: 360);
    titlePainter.paint(
      canvas,
      Offset((400 - titlePainter.width) / 2, 310),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(400, 400);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempFile = File('${Directory.systemTemp.path}/icon_${type}_${DateTime.now().millisecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    return tempFile.path;
  }

  /// Periodically fetch remote notifications
  void startRemoteSyncTimer() {
    _remoteSyncTimer?.cancel();
    syncOnlineNotifications();
    _remoteSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      syncOnlineNotifications();
    });
  }

  void stopRemoteSyncTimer() {
    _remoteSyncTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  void startSavedItemsReminderTimer() {
    _savedItemsReminderTimer?.cancel();
    // Run an initial check after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      checkAndTriggerSavedItemsReminder();
    });
    // Check every 30 seconds if a reminder is due
    _savedItemsReminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkAndTriggerSavedItemsReminder();
    });
  }

  void stopSavedItemsReminderTimer() {
    _savedItemsReminderTimer?.cancel();
  }

  void _handleNotificationNavigation(String postId) async {
    // Wait briefly if PostStore is still initializing (e.g., from cold start)
    int retries = 0;
    while (PostStore.instance.posts.isEmpty && retries < 6) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    // Try finding UserPost first
    UserPost? userPost = PostStore.instance.posts
        .where((p) => p.id == postId)
        .firstOrNull;

    PostModel? postModel;
    if (userPost == null) {
      // Try finding in PredefinedPost
      final idx = PostStore.predefinedPosts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        postModel = PostStore.predefinedPosts[idx];
      }
    }

    final navState = MyApp.navigatorKey.currentState;
    if (navState != null) {
      if (userPost != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(userPost: userPost),
          ),
        );
      } else if (postModel != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(postModel: postModel),
          ),
        );
      }
    }
  }

  void subscribeToNotifications(String currentUserId) {
    if (_realtimeChannel != null) return;

    _realtimeChannel = Supabase.instance.client
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final notif = NotificationModel.fromJson(payload.newRecord);
              
              // Filter locally for the current user
              if (notif.toUserId != currentUserId) return;
              
              final currentIds = notificationsNotifier.value.map((n) => n.id).toSet();
              if (!currentIds.contains(notif.id)) {
                notificationsNotifier.value = [notif, ...notificationsNotifier.value];
                _playNotificationSound();
                _updateLauncherBadge();
                showLocalNotification(
                  id: Random().nextInt(100000),
                  title: notif.username,
                  body: notif.previewText,
                  payload: notif.postId != null ? 'post:${notif.postId}' : null,
                );


              }
            } catch (e) {
              debugPrint('Error processing realtime notification: $e');
            }
          },
        )
        .onPostgresChanges(
          // Also listen for updates (e.g. friend_request → friend_request_accepted)
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final updatedNotif = NotificationModel.fromJson(payload.newRecord);
              
              // Filter locally for the current user
              if (updatedNotif.toUserId != currentUserId) return;

              // Replace the in-memory copy with the updated version
              notificationsNotifier.value = notificationsNotifier.value.map((n) {
                return n.id == updatedNotif.id ? updatedNotif : n;
              }).toList();
              _updateLauncherBadge();
            } catch (e) {
              debugPrint('Error processing realtime notification update: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          callback: (payload) {
            try {
              final deletedId = payload.oldRecord['id']?.toString();
              if (deletedId != null) {
                notificationsNotifier.value = notificationsNotifier.value.where((n) => n.id != deletedId).toList();
                _updateLauncherBadge();
              }
            } catch (e) {
              debugPrint('Error processing realtime notification delete: $e');
            }
          },
        );
    _realtimeChannel!.subscribe();
  }


  Future<void> syncOnlineNotifications() async {
    try {
      final currentUserId = UserStore.instance.currentUser?.userId;
      if (currentUserId == null) return;

      // Ensure Realtime Channel subscription is running
      subscribeToNotifications(currentUserId);

      final response = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('to_user_id', currentUserId)
          .order('created_at', ascending: false)
          .limit(50);

      final List<NotificationModel> remoteNotifications = [];
      for (var item in response) {
        try {
          remoteNotifications.add(
            NotificationModel.fromJson(item),
          );
        } catch (e) {
          debugPrint("Error parsing remote notification: $e");
        }
      }

      // Build a map from remote notifications for fast lookup
      final remoteMap = {for (var n in remoteNotifications) n.id: n};
      final currentIds = notificationsNotifier.value.map((n) => n.id).toSet();

      bool hasNew = false;
      bool hasUpdated = false;

      // Update any existing in-memory notifications whose DB record changed
      final List<NotificationModel> mergedList = notificationsNotifier.value.map((n) {
        final remote = remoteMap[n.id];
        if (remote != null && remote.actionType != n.actionType) {
          hasUpdated = true;
          return remote; // replace with latest version from DB
        }
        return n;
      }).toList();

      // Add brand-new notifications not yet in memory
      for (var notif in remoteNotifications) {
        if (!currentIds.contains(notif.id)) {
          mergedList.add(notif);
          hasNew = true;
        }
      }

      if (hasNew || hasUpdated) {
        // Sort newest first
        mergedList.sort((a, b) {
          final aDate = DateTime.tryParse(a.timestamp) ?? DateTime.now();
          final bDate = DateTime.tryParse(b.timestamp) ?? DateTime.now();
          return bDate.compareTo(aDate);
        });
        notificationsNotifier.value = mergedList;
        if (hasNew && currentIds.isNotEmpty) {
          _playNotificationSound();
        }
        _updateLauncherBadge();

        // Show local heads-up for the most recent NEW notification
        // BUT do not show it if the in-memory list was empty initially (to prevent startup notifications)
        if (hasNew && remoteNotifications.isNotEmpty && currentIds.isNotEmpty) {
          final mostRecent = remoteNotifications.first;
          if (!currentIds.contains(mostRecent.id)) {
            await showLocalNotification(
              id: Random().nextInt(100000),
              title: mostRecent.username,
              body: mostRecent.previewText,
              payload: mostRecent.postId != null ? 'post:${mostRecent.postId}' : null,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing remote notifications: $e");
    }
  }

  Future<void> uploadNotificationOnline(NotificationModel notif) async {
    try {
      final dbNotif = {
        'id': notif.id,
        'to_user_id': notif.toUserId,
        'from_user_id': notif.fromUserId ?? UserStore.instance.currentUser?.userId,
        'avatar_seed': notif.avatarSeed,
        'avatar_initial': notif.avatarInitial,
        'avatar_color': notif.avatarColor.toARGB32(),
        'username': notif.username,
        'preview_text': notif.previewText,
        'action_type': notif.actionType,
        'post_id': notif.postId,
        'is_read': notif.isRead,
      };

      await Supabase.instance.client.from('notifications').insert(dbNotif);
      debugPrint("Notification uploaded successfully to Supabase.");
    } catch (e) {
      debugPrint("Error uploading remote notification: $e");
    }
  }

  final List<Map<String, String>> _mockActivities = [
    {
      'username': 'emma.visuals',
      'action': 'liked your post',
      'initial': 'E',
      'color': '0xFF9B59B6',
    },
    {
      'username': 'dan_code',
      'action': 'commented: "Clean work! 🚀"',
      'initial': 'D',
      'color': '0xFF2ECC71',
    },
    {
      'username': 'jess.shoots',
      'action': 'shared your post',
      'initial': 'J',
      'color': '0xFFFF1744',
    },
    {
      'username': 'zack.fit',
      'action': 'started following you',
      'initial': 'Z',
      'color': '0xFFF1C40F',
    },
    {
      'username': 'sara.m',
      'action': 'posted a new photo',
      'initial': 'S',
      'color': '0xFF7B61FF',
    },
  ];

  void _playNotificationSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;

      await _soundPlayer.stop();
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
      avatarSeed: activity['username'],
      avatarInitial: activity['initial']!,
      avatarColor: Color(int.parse(activity['color']!)),
      username: activity['username']!,
      previewText: activity['action']!,
      timestamp: DateTime.now().toIso8601String(),
      isRead: false,
    );

    notificationsNotifier.value = [newNotif, ...notifications];

    _playNotificationSound();
    _updateLauncherBadge();

    await showLocalNotification(
      id: rand.nextInt(100000),
      title: activity['username']!,
      body: activity['action']!,
    );
  }

  /// Triggers a notification for a user action (like, share, save).
  void triggerUserActionNotification({
    required String action,
    required String postTitle,
    String? author,
    String? postAuthorId,
    String? postId,
    bool isIncoming = false,
    String? remoteUsername,
    Color? remoteAvatarColor,
    String? remoteAvatarInitial,
    String? remoteAvatarAssetPath,
  }) async {
    final rand = Random();
    final String id = 'user-${DateTime.now().millisecondsSinceEpoch}';
    final actorName = isIncoming
        ? (remoteUsername ?? 'Someone')
        : (author != null && author.isNotEmpty ? author : 'Someone');

    String body = '';
    String title = '';
    Color avatarColor;
    String initial;
    String? avatarAsset;

    if (isIncoming) {
      avatarColor = remoteAvatarColor ?? const Color(0xFFE24A6A);
      initial = remoteAvatarInitial ?? actorName[0].toUpperCase();
      avatarAsset = remoteAvatarAssetPath;
      if (action == 'liked') {
        title = 'Someone liked your post';
        body = '$actorName liked your post: "$postTitle"';
      } else if (action == 'shared') {
        title = 'Someone shared your post';
        body = '$actorName shared your post: "$postTitle"';
      } else if (action.startsWith('commented')) {
        title = 'Someone commented on your post';
        body = '$actorName commented on your post: "$postTitle"';
      } else {
        title = 'Post activity';
        body = '$actorName interacted with "$postTitle"';
      }
    } else {
      avatarColor = action == 'liked'
          ? const Color(0xFFE24A6A)
          : action == 'shared'
              ? const Color(0xFF7B61FF)
              : const Color(0xFF2ECC71);
      initial = action == 'liked'
          ? 'L'
          : action == 'shared'
              ? 'S'
              : 'B';
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
      } else if (action.startsWith('commented')) {
        title = 'Comment Posted';
        body = 'You commented on $actorName\'s post: "$postTitle"';
      }
    }

    final String currentUserId =
        UserStore.instance.currentUser?.userId ?? 'You';

    if (isIncoming) {
      final newNotif = NotificationModel(
        id: id,
        avatarAssetPath: avatarAsset,
        avatarSeed: actorName,
        avatarInitial: initial,
        avatarColor: avatarColor,
        username: actorName,
        previewText: body,
        timestamp: DateTime.now().toIso8601String(),
        isRead: false,
        toUserId: currentUserId,
        postId: postId,
        actionType: action,
      );

      notificationsNotifier.value = [newNotif, ...notifications];

      _playNotificationSound();
      _updateLauncherBadge();

      await showLocalNotification(
        id: rand.nextInt(100000),
        title: title,
        body: body,
        payload: postId != null ? 'post:$postId' : null,
      );


    } else {
      if (postAuthorId != null && postAuthorId != currentUserId) {
        final remoteNotif = NotificationModel(
          id: 'remote-${DateTime.now().millisecondsSinceEpoch}',
          avatarSeed: DiceAvatar.seedNotifier.value,
          avatarInitial: initial,
          avatarColor: avatarColor,
          username: currentUserId,
          previewText: (action == 'liked'
              ? 'liked your post: "$postTitle"'
              : action == 'shared'
                  ? 'shared your post: "$postTitle"'
                  : action.startsWith('commented')
                      ? 'commented on your post: "$postTitle"'
                      : 'saved your post: "$postTitle"'),
          timestamp: DateTime.now().toIso8601String(),
          isRead: false,
          toUserId: postAuthorId,
          fromUserId: currentUserId,
          postId: postId,
          actionType: action,
        );
        uploadNotificationOnline(remoteNotif);
      }
    }
  }

  /// Triggers a reminder notification for a vault item.
  void triggerVaultReminderNotification(String title) async {
    final String id = 'vault-${DateTime.now().millisecondsSinceEpoch}';
    const Color vaultColor = Color(0xFFF39C12);
    const String vaultInitial = 'V';
    final String body =
        'You added a new memory: "$title". Review it in Self Save.';

    final newNotif = NotificationModel(
      id: id,
      avatarSeed: 'saverites_vault',
      avatarInitial: vaultInitial,
      avatarColor: vaultColor,
      username: 'Saverites Vault',
      previewText: body,
      timestamp: DateTime.now().toIso8601String(),
      isRead: false,
    );

    notificationsNotifier.value = [newNotif, ...notifications];

    _playNotificationSound();
    _updateLauncherBadge();

    await showLocalNotification(
      id: Random().nextInt(100000),
      title: 'Saverites Vault Reminder',
      body: 'You added a new memory: "$title"',
    );
  }

  /// Renders a native heads-up overlay notification on the OS level.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imagePath,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;
    } catch (e) {
      debugPrint("Error reading notification setting: $e");
    }

    String? localImagePath = imagePath;
    if (imagePath != null && imagePath.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(imagePath);
        final tempFile = File('${Directory.systemTemp.path}/${imagePath.split('/').last}');
        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          await tempFile.writeAsBytes(
            byteData.buffer.asUint8List(
              byteData.offsetInBytes,
              byteData.lengthInBytes,
            ),
          );
        }
        localImagePath = tempFile.path;
      } catch (e) {
        debugPrint("Error copying asset image for notification: $e");
        localImagePath = null;
      }
    }

    StyleInformation? styleInformation;
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final file = File(localImagePath);
      if (file.existsSync()) {
        styleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(localImagePath),
          largeIcon: FilePathAndroidBitmap(localImagePath),
          contentTitle: title,
          summaryText: body,
        );
      }
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'saverites_notifications_push',
      'Saverites Notifications',
      channelDescription: 'Notifications for likes, comments, follows and posts on Saverites',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Saverites',
      playSound: true,
      channelShowBadge: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: styleInformation,
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    try {
      await _localNotifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: payload ?? 'notification_screen',
      );
    } catch (e) {
      debugPrint("Error showing local notification: $e");
    }
  }

  /// Marks all current notifications as read and resets badge counts.
  void markAllAsRead() async {
    // Use auth UUID because to_user_id stores auth UUIDs (not userId strings)
    final currentAuthUuid = Supabase.instance.client.auth.currentUser?.id;
    if (currentAuthUuid != null) {
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true})
            .eq('to_user_id', currentAuthUuid);
      } catch (e) {
        debugPrint('Error marking notifications as read on database: $e');
      }
    }

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
        toUserId: n.toUserId,
        postId: n.postId,
        actionType: n.actionType,
        fromUserId: n.fromUserId,
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

      final storedInterval =
          prefs.getString('savedItemsReminderInterval') ?? 'Once a Day';
      final interval = storedInterval == 'Always' ? 'Once a Day' : storedInterval;
      if (interval == 'Never') return;

      final savedPredefinedCount = PostStore.instance.savedSocialPostIds.length;
      final savedUserPosts = PostStore.instance.posts
          .where((p) => p.savedInProfile)
          .toList();
      final totalSaved = savedPredefinedCount + savedUserPosts.length;

      if (totalSaved == 0) return;

      final lastReminderMs =
          prefs.getInt('lastSavedItemsReminderTimestamp') ?? 0;
      final lastReminder = DateTime.fromMillisecondsSinceEpoch(lastReminderMs);
      final now = DateTime.now();

      Duration checkDuration;
      if (interval == 'Test (1 Min)') {
        checkDuration = const Duration(minutes: 1);
      } else if (interval == 'Once a Day') {
        checkDuration = const Duration(days: 1);
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
        await prefs.setInt(
          'lastSavedItemsReminderTimestamp',
          now.millisecondsSinceEpoch,
        );

        String notifTitle = "Saved Memory Reminder";
        String notifDesc = "You saved this item to review later.";
        String? targetPostId;
        String? notifImagePath;

        if (savedUserPosts.isNotEmpty &&
            (savedPredefinedCount == 0 || Random().nextBool())) {
          final rand = Random();
          final post = savedUserPosts[rand.nextInt(savedUserPosts.length)];
          targetPostId = post.id;
          notifTitle = post.title;

          switch (post.type) {
            case 'checklist':
              final List<String> uncheckedItems = [];
              if (post.checklistItems != null && post.checklistStates != null) {
                for (int i = 0; i < post.checklistItems!.length; i++) {
                  if (i < post.checklistStates!.length && !post.checklistStates![i]) {
                    uncheckedItems.add(post.checklistItems![i]);
                  }
                }
              }
              if (uncheckedItems.isNotEmpty) {
                notifDesc = "Remember to finish: ${uncheckedItems.take(2).join(', ')}${uncheckedItems.length > 2 ? ' and ${uncheckedItems.length - 2} more' : ''}";
              } else {
                notifDesc = "Review your checklist";
              }
              break;

            case 'audio':
              notifDesc = "Listen back to your voice memo${post.duration != null ? ' (${post.duration})' : ''}";
              break;

            case 'link':
              final domain = Uri.tryParse(post.url ?? '')?.host ?? '';
              notifDesc = "Review saved article${domain.isNotEmpty ? ' ($domain)' : ''}";
              break;

            case 'contact':
              notifDesc = "Reach out to: ${post.contactName ?? post.title}${post.contactPhone != null ? ' (${post.contactPhone})' : ''}";
              break;

            case 'code':
              notifDesc = "Review your code snippet";
              break;

            case 'document':
              notifDesc = "Open and review document";
              break;

            case 'image':
              notifDesc = "Take a look at your photo";
              if (post.imagePath != null && File(post.imagePath!).existsSync()) {
                notifImagePath = post.imagePath;
              } else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
                final ext = post.imageUrl!.split('.').last.split('?').first;
                final tempFile = File('${Directory.systemTemp.path}/img_${post.id}.$ext');
                if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
                  notifImagePath = tempFile.path;
                }
              }
              break;

            case 'video':
              notifDesc = "Watch your saved video";
              if (post.videoPath != null && File(post.videoPath!).existsSync()) {
                try {
                  final thumb = await VideoThumbnail.thumbnailFile(
                    video: post.videoPath!,
                    thumbnailPath: Directory.systemTemp.path,
                    imageFormat: ImageFormat.JPEG,
                    quality: 75,
                  );
                  if (thumb != null) {
                    notifImagePath = thumb;
                  }
                } catch (e) {
                  debugPrint("Error generating video thumbnail: $e");
                }
              } else if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
                try {
                  final thumb = await VideoThumbnail.thumbnailFile(
                    video: post.videoUrl!,
                    thumbnailPath: Directory.systemTemp.path,
                    imageFormat: ImageFormat.JPEG,
                    quality: 75,
                  );
                  if (thumb != null) {
                    notifImagePath = thumb;
                  }
                } catch (e) {
                  debugPrint("Error generating remote video thumbnail: $e");
                }
              }
              break;

            case 'text':
            default:
              final preview = post.body.trim();
              notifDesc = preview.isNotEmpty
                  ? "Look back at note: \"${preview.length > 40 ? '${preview.substring(0, 40)}...' : preview}\""
                  : "Review your note";
              break;
          }

          // Generate Canvas Icon Thumbnail if still null
          if (notifImagePath == null) {
            try {
              notifImagePath = await _generateIconThumbnail(post.type ?? 'text', post.title);
            } catch (e) {
              debugPrint("Error generating dynamic icon: $e");
            }
          }
        } else if (PostStore.instance.savedSocialPostIds.isNotEmpty) {
          final socialSaves = PostStore.predefinedPosts
              .where(
                (p) => PostStore.instance.savedSocialPostIds.contains(p.id),
              )
              .toList();
          if (socialSaves.isNotEmpty) {
            final rand = Random();
            final post = socialSaves[rand.nextInt(socialSaves.length)];
            targetPostId = post.id;
            notifTitle = post.title ?? 'Saved Social Post';

            if (post.mediaType == PostMediaType.video) {
              notifDesc = "Watch back video post by @${post.username ?? 'someone'}";
              if (post.mediaAssetPath.isNotEmpty) {
                notifImagePath = post.mediaAssetPath;
              }
            } else {
              notifDesc = "Take a look at post by @${post.username ?? 'someone'}";
              if (post.mediaAssetPath.isNotEmpty) {
                notifImagePath = post.mediaAssetPath;
              }
            }
          }
        }

        if (targetPostId == null) return;

        final String notifId = 'reminder-${now.millisecondsSinceEpoch}';
        final String notifBody = "Hey! Check what you saved before you forget.\n$notifDesc";

        final newNotif = NotificationModel(
          id: notifId,
          avatarSeed: 'saverites_reminder',
          avatarInitial: 'R',
          avatarColor: const Color(0xFFFF9500),
          username: 'Saverites Reminder',
          previewText: notifBody,
          timestamp: DateTime.now().toIso8601String(),
          isRead: false,
          postId: targetPostId,
          actionType: 'saved',
        );

        notificationsNotifier.value = [newNotif, ...notifications];

        _playNotificationSound();
        _updateLauncherBadge();

        await showLocalNotification(
          id: Random().nextInt(100000),
          title: notifTitle,
          body: notifBody,
          payload: 'post:$targetPostId',
          imagePath: notifImagePath,
        );
      }
    } catch (e) {
      debugPrint("Error running saved items reminder check: $e");
    }
  }

  Future<void> acceptFriendRequest(NotificationModel notification) async {
    try {
      final currentUserId = UserStore.instance.currentUser?.userId;
      if (currentUserId == null) return;

      // In the new system, fromUserId stores the sender's username handle.
      // If empty/missing, fallback to notification.username.
      final senderUsername = (notification.fromUserId != null && notification.fromUserId!.isNotEmpty)
          ? notification.fromUserId!
          : notification.username;

      // Resolve UUID for the sender (needed for user_follows UUID constraints)
      String? resolvedSenderUuid;
      final senderProfileRes = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('user_id', senderUsername)
          .maybeSingle();
      resolvedSenderUuid = senderProfileRes?['id'] as String?;

      // Resolve UUID for receiver (current user)
      final receiverUuid = Supabase.instance.client.auth.currentUser?.id;

      if (resolvedSenderUuid != null && receiverUuid != null) {
        // 1. Sender follows receiver
        try {
          await Supabase.instance.client.from('user_follows').insert({
            'follower_id': resolvedSenderUuid,
            'followed_id': receiverUuid,
          });
        } catch (e) {
          debugPrint("Follow insert sender->receiver failed: $e");
        }

        // 2. Receiver follows sender (mutual friend)
        try {
          await Supabase.instance.client.from('user_follows').insert({
            'follower_id': receiverUuid,
            'followed_id': resolvedSenderUuid,
          });
        } catch (e) {
          debugPrint("Follow insert receiver->sender failed: $e");
        }

        // 3. Notify the original sender that their request was accepted
        try {
          final acceptNotifId = 'faccepted-${DateTime.now().millisecondsSinceEpoch}';
          final avatarSeed = DiceAvatar.seedNotifier.value;
          await Supabase.instance.client.from('notifications').insert({
            'id': acceptNotifId,
            'to_user_id': senderUsername,
            'from_user_id': currentUserId,
            'avatar_seed': avatarSeed,
            'avatar_initial': currentUserId.isNotEmpty ? currentUserId[0].toUpperCase() : 'U',
            'avatar_color': const Color(0xFF2ECC71).toARGB32(),
            'username': currentUserId,
            'preview_text': 'accepted your friend request',
            'action_type': 'friend_request_accepted',
            'is_read': false,
          });
        } catch (e) {
          debugPrint("Acceptance notification to sender failed: $e");
        }
      }

      // Update original notification status (hides Accept/Decline buttons)
      await Supabase.instance.client
          .from('notifications')
          .update({
            'action_type': 'friend_request_accepted',
            'preview_text': 'is now your friend',
          })
          .eq('id', notification.id);

      await syncOnlineNotifications();
    } catch (e) {
      debugPrint("Error accepting friend request: $e");
    }
  }


  Future<void> denyFriendRequest(NotificationModel notification) async {
    try {
      // Update notification status
      await Supabase.instance.client
          .from('notifications')
          .update({
            'action_type': 'friend_request_denied',
            'preview_text': 'friend request declined',
          })
          .eq('id', notification.id);

      await syncOnlineNotifications();
    } catch (e) {
      debugPrint("Error denying friend request: $e");
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
