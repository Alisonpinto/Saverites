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
  });
}
