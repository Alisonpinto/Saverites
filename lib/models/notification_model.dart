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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'avatarAssetPath': avatarAssetPath,
      'avatarSeed': avatarSeed,
      'avatarInitial': avatarInitial,
      'avatarColor': avatarColor.value,
      'username': username,
      'previewText': previewText,
      'timestamp': timestamp,
      'isRead': isRead,
      'toUserId': toUserId,
      'postId': postId,
      'actionType': actionType,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      avatarAssetPath: json['avatarAssetPath'] as String?,
      avatarSeed: json['avatarSeed'] as String?,
      avatarInitial: json['avatarInitial'] as String? ?? '?',
      avatarColor: json['avatarColor'] != null
          ? Color(json['avatarColor'] as int)
          : const Color(0xFF7B61FF),
      username: json['username'] as String? ?? 'Unknown',
      previewText: json['previewText'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? 'now',
      isRead: json['isRead'] as bool? ?? false,
      toUserId: json['toUserId'] as String?,
      postId: json['postId'] as String?,
      actionType: json['actionType'] as String?,
    );
  }
}
