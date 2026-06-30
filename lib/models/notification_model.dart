/// Data model for a single notification item.
///
/// All fields map directly to Firestore document fields.
/// Replace the static sample list in [NotificationScreen] with a
/// `StreamBuilder<List<NotificationModel>>` when the backend is ready.
library;

import 'package:flutter/material.dart';

class NotificationModel {
  /// Firestore document ID.
  final String id;

  /// Asset path or future network URL for the sender's avatar.
  /// Falls back to [avatarInitial] + [avatarColor] if null.
  final String? avatarAssetPath;

  /// DiceBear seed for the avatar SVG. When set, renders a DiceBear
  /// notionists avatar instead of the initials fallback.
  final String? avatarSeed;

  /// Single character shown inside the avatar circle when no image is set.
  final String avatarInitial;

  /// Background colour of the initials avatar.
  final Color avatarColor;

  /// Display name of the sender.
  final String username;

  /// Short notification body (e.g. "liked your post").
  final String previewText;

  /// Human-readable time string (e.g. "52m", "2h", "Yesterday").
  final String timestamp;

  /// Whether the notification has been seen by the user.
  final bool isRead;

  /// The user ID this notification is intended for
  final String? toUserId;

  /// The post ID this notification relates to (for deep linking)
  final String? postId;

  /// The type of action (e.g. 'liked', 'shared', 'saved')
  final String? actionType;

  /// The user ID of who sent this notification (auth UUID)
  final String? fromUserId;

  const NotificationModel({
    required this.id,
    this.avatarAssetPath,
    this.avatarSeed,
    required this.avatarInitial,
    required this.avatarColor,
    required this.username,
    required this.previewText,
    required this.timestamp,
    this.isRead = false,
    this.toUserId,
    this.postId,
    this.actionType,
    this.fromUserId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatarAssetPath': avatarAssetPath,
      'avatarSeed': avatarSeed,
      'avatarInitial': avatarInitial,
      'avatarColor': avatarColor.toARGB32(),
      'username': username,
      'previewText': previewText,
      'timestamp': timestamp,
      'isRead': isRead,
      'toUserId': toUserId,
      'postId': postId,
      'actionType': actionType,
      'fromUserId': fromUserId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      avatarAssetPath: (json['avatarAssetPath'] ?? json['avatar_asset_path']) as String?,
      avatarSeed: (json['avatarSeed'] ?? json['avatar_seed']) as String?,
      avatarInitial: (json['avatarInitial'] ?? json['avatar_initial']) as String? ?? '?',
      avatarColor: json['avatarColor'] != null
          ? Color(json['avatarColor'] as int)
          : json['avatar_color'] != null
              ? Color(json['avatar_color'] as int)
              : const Color(0xFF7B61FF),
      username: json['username'] as String? ?? 'Unknown',
      previewText: (json['previewText'] ?? json['preview_text']) as String? ?? '',
      timestamp: (json['timestamp'] ?? json['created_at']) as String? ?? 'now',
      isRead: (json['isRead'] ?? json['is_read']) as bool? ?? false,
      toUserId: (json['toUserId'] ?? json['to_user_id']) as String?,
      postId: (json['postId'] ?? json['post_id']) as String?,
      actionType: (json['actionType'] ?? json['action_type']) as String?,
      fromUserId: (json['fromUserId'] ?? json['from_user_id']) as String?,
    );
  }
}
