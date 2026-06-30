import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../widgets/dice_avatar.dart';
import '../widgets/in_app_notification.dart';
import 'post_store.dart';
import 'user_store.dart';

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
                );

                InAppNotificationHelper.show(
                  body: notif.previewText,
                  showMedia: false,
                  avatarInitial: notif.avatarInitial,
                  avatarColor: notif.avatarColor,
                  avatarAssetPath: notif.avatarAssetPath,
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
        if (hasNew) {
          _playNotificationSound();
        }
        _updateLauncherBadge();

        // Show local heads-up for the most recent NEW notification
        if (hasNew && remoteNotifications.isNotEmpty) {
          final mostRecent = remoteNotifications.first;
          if (!currentIds.contains(mostRecent.id)) {
            await showLocalNotification(
              id: Random().nextInt(100000),
              title: mostRecent.username,
              body: mostRecent.previewText,
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
      );

      InAppNotificationHelper.show(
        body: body,
        showMedia: false,
        avatarInitial: initial,
        avatarColor: avatarColor,
        avatarAssetPath: avatarAsset,
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
      avatarSeed: 'memoria_vault',
      avatarInitial: vaultInitial,
      avatarColor: vaultColor,
      username: 'Memoria Vault',
      previewText: body,
      timestamp: DateTime.now().toIso8601String(),
      isRead: false,
    );

    notificationsNotifier.value = [newNotif, ...notifications];

    _playNotificationSound();
    _updateLauncherBadge();

    await showLocalNotification(
      id: Random().nextInt(100000),
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notificationsEnabled') ?? true;
      if (!enabled) return;
    } catch (e) {
      debugPrint("Error reading notification setting: $e");
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'memoria_notifications_silent',
      'Memoria Notifications',
      channelDescription: 'Notifications for likes, comments, and posts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: false,
    );
    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
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

      final interval =
          prefs.getString('savedItemsReminderInterval') ?? 'Always';
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
      if (interval == 'Always') {
        checkDuration = const Duration(seconds: 45);
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

        String title = "your saved items";
        String? localImagePath;
        String? assetImagePath;

        if (savedUserPosts.isNotEmpty &&
            (savedPredefinedCount == 0 || Random().nextBool())) {
          final rand = Random();
          final post = savedUserPosts[rand.nextInt(savedUserPosts.length)];
          title = '"${post.title}"';
          localImagePath = post.imagePath;
        } else if (PostStore.instance.savedSocialPostIds.isNotEmpty) {
          final socialSaves = PostStore.predefinedPosts
              .where(
                (p) => PostStore.instance.savedSocialPostIds.contains(p.id),
              )
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
          avatarSeed: 'memoria_reminder',
          avatarInitial: 'R',
          avatarColor: const Color(0xFFFF9500),
          username: 'Memoria Reminder',
          previewText: body,
          timestamp: DateTime.now().toIso8601String(),
          isRead: false,
        );

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
