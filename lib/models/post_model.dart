/// Data model for a single feed post.
///
/// Designed to be backend-agnostic: currently uses local asset paths,
/// but [mediaAssetPath] can be swapped for a network URL when Firebase
/// is wired up. All action counts are plain [int] so they can be written
/// back to Firestore without any conversion.
library;

import 'package:flutter/material.dart';

/// The kind of media this post carries.
enum PostMediaType { image, video }

class PostModel {
  /// Unique identifier — will map to a Firestore document ID.
  final String id;

  /// Asset path (e.g. `'assets/images/outfit.png'`) or future network URL.
  final String mediaAssetPath;

  final PostMediaType mediaType;

  final int likesCount;
  final int savesCount;
  final int sharesCount;

  /// Fixed pixel height for the media area, enabling the masonry layout.
  final double cardHeight;

  // ── Visual customisation (card-type specific) ──────────────────────────

  /// Accent border/background colour used by special card types (e.g. panda).
  final Color? accentColor;

  /// Inner padding around the media widget, used when the card has a
  /// coloured accent border that should show through.
  final EdgeInsets? mediaPadding;

  /// Override for the media clip radius (defaults to top-corners only).
  final BorderRadius? mediaBorderRadius;

  /// Optional widget rendered on top of the media (text overlays, etc.).
  final Widget? mediaOverlay;

  // ── User / content fields (populated from Firebase later) ──────────────

  /// Display name of the post author.
  final String? username;

  /// Asset path or network URL for the author's profile picture.
  final String? avatarAssetPath;

  /// Short title shown prominently in the detail view.
  final String? title;

  /// Longer body text / caption.
  final String? description;

  /// Optional external link attached to the post.
  final String? url;

  const PostModel({
    required this.id,
    required this.mediaAssetPath,
    this.mediaType = PostMediaType.image,
    required this.likesCount,
    required this.savesCount,
    required this.sharesCount,
    required this.cardHeight,
    this.accentColor,
    this.mediaPadding,
    this.mediaBorderRadius,
    this.mediaOverlay,
    // User / content
    this.username,
    this.avatarAssetPath,
    this.title,
    this.description,
    this.url,
  });

  /// Creates a copy with overridden fields — useful for optimistic UI updates.
  PostModel copyWith({
    int? likesCount,
    int? savesCount,
    int? sharesCount,
  }) {
    return PostModel(
      id: id,
      mediaAssetPath: mediaAssetPath,
      mediaType: mediaType,
      likesCount: likesCount ?? this.likesCount,
      savesCount: savesCount ?? this.savesCount,
      sharesCount: sharesCount ?? this.sharesCount,
      cardHeight: cardHeight,
      accentColor: accentColor,
      mediaPadding: mediaPadding,
      mediaBorderRadius: mediaBorderRadius,
      mediaOverlay: mediaOverlay,
      username: username,
      avatarAssetPath: avatarAssetPath,
      title: title,
      description: description,
      url: url,
    );
  }
}
