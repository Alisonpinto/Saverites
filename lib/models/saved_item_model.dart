/// Data model for an item saved to the user's profile.
///
/// [SaveSource.social] — saved from the Feed (via the bookmark action on a PostCard).
/// [SaveSource.self]   — manually saved by the user inside the app (Write a Post / Save a Item).
///
/// Both sources share this model so a single grid widget can render either list.
/// When Firebase is connected, map Firestore documents to [SavedItemModel] via
/// a `fromJson` factory. The [postId] field links back to the originating post.
library;

enum SaveSource { social, self }

class SavedItemModel {
  /// Firestore document ID for this saved-item record.
  final String id;

  /// ID of the originating post (social saves only).
  final String? postId;

  /// Asset path or future network URL for the thumbnail.
  final String? mediaAssetPath;

  /// Card height in pixels — drives the masonry layout.
  final double cardHeight;

  final SaveSource source;

  /// When the user saved this item.
  final DateTime savedAt;

  /// Optional title (used by self-saved items).
  final String? title;

  const SavedItemModel({
    required this.id,
    this.postId,
    this.mediaAssetPath,
    required this.cardHeight,
    required this.source,
    required this.savedAt,
    this.title,
  });
}
