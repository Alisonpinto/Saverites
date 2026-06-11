import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../widgets/in_app_notification.dart';
import 'rich_text_controller.dart';
import 'notification_manager.dart';

/// A single user-created post (text + optional media file path).
class UserPost {
  final String id;
  final String title;
  final String body;
  final String? url;

  /// Absolute path to a local image file, or null if no image attached.
  final String? imagePath;

  /// Absolute path to a local video file, or null if no video attached.
  final String? videoPath;

  /// Whether to also save this post in the profile grid.
  final bool savedInProfile;

  final DateTime createdAt;

  /// Formatting character-by-character styles.
  final List<RichStyle>? charStyles;

  // New fields for Save to Memoria workflow:
  final String? type;            // "image", "video", "document", "audio", "contact", "link", "text", "checklist", "code"
  final String? filePath;        // local file path for document/audio/vcf
  final String? contactName;     // contact full name
  final String? contactPhone;    // contact phone number
  final String? duration;        // audio duration
  final List<String>? checklistItems; // checklist entries
  final List<bool>? checklistStates;  // checkbox states

  UserPost({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    this.imagePath,
    this.videoPath,
    required this.savedInProfile,
    required this.createdAt,
    this.charStyles,
    this.type,
    this.filePath,
    this.contactName,
    this.contactPhone,
    this.duration,
    this.checklistItems,
    this.checklistStates,
  });
}

/// Global reactive store for user-created posts.
///
/// Both [FeedScreen] and [ProfileScreen] listen to [postsNotifier]
/// so that when the user posts, both update simultaneously.
class PostStore {
  PostStore._();
  static final PostStore instance = PostStore._();

  /// All published posts, newest first.
  final ValueNotifier<List<UserPost>> postsNotifier =
      ValueNotifier<List<UserPost>>([]);

  List<UserPost> get posts => postsNotifier.value;

  /// Set of saved predefined post IDs.
  final ValueNotifier<Set<String>> savedSocialPostIdsNotifier =
      ValueNotifier<Set<String>>({});

  Set<String> get savedSocialPostIds => savedSocialPostIdsNotifier.value;

  /// Set of liked post IDs.
  final ValueNotifier<Set<String>> likedPostIdsNotifier =
      ValueNotifier<Set<String>>({});

  Set<String> get likedPostIds => likedPostIdsNotifier.value;

  /// Toggles the liked status of a post.
  void toggleLikedPost(String postId) {
    final current = Set<String>.from(likedPostIds);
    bool isLiked = false;
    if (current.contains(postId)) {
      current.remove(postId);
    } else {
      current.add(postId);
      isLiked = true;
    }
    likedPostIdsNotifier.value = current;

    if (isLiked) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'liked',
        postTitle: details['title']!,
        author: details['author']!,
      );
    }
  }

  /// Helper to get post details (title and author) for notifications.
  Map<String, String> getPostDetails(String postId) {
    // 1. Search in predefinedPosts
    for (final p in predefinedPosts) {
      if (p.id == postId) {
        return {'title': p.title ?? 'Untitled Post', 'author': p.username ?? 'someone'};
      }
    }
    // 2. Search in user posts
    for (final p in posts) {
      if (p.id == postId) {
        return {'title': p.title, 'author': 'You'};
      }
    }
    return {'title': 'Untitled Post', 'author': 'someone'};
  }

  /// Adds a post and notifies all listeners.
  void addPost(UserPost post) {
    postsNotifier.value = [post, ...postsNotifier.value];
    if (post.savedInProfile) {
      NotificationManager.instance.triggerVaultReminderNotification(post.title);
      InAppNotificationHelper.show(
        body: post.title,
        imagePath: post.imagePath,
        showMedia: true,
      );
    } else {
      savedSocialPostIdsNotifier.value = {post.id, ...savedSocialPostIdsNotifier.value};
    }
  }

  /// Toggles the savedInProfile status of a post and notifies listeners.
  void toggleSavedInProfile(String postId) {
    bool isSaved = false;
    postsNotifier.value = postsNotifier.value.map((post) {
      if (post.id == postId) {
        isSaved = !post.savedInProfile;
        return UserPost(
          id: post.id,
          title: post.title,
          body: post.body,
          url: post.url,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: !post.savedInProfile,
          createdAt: post.createdAt,
          charStyles: post.charStyles,
          type: post.type,
          filePath: post.filePath,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
        );
      }
      return post;
    }).toList();

    if (isSaved) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'saved',
        postTitle: details['title']!,
        author: details['author']!,
      );
    }
  }

  /// Updates the body text and styling of a post and notifies listeners.
  void updatePostText(String postId, String newBody, List<RichStyle>? charStyles) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (post.id == postId) {
        return UserPost(
          id: post.id,
          title: post.title,
          body: newBody,
          url: post.url,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: post.savedInProfile,
          createdAt: post.createdAt,
          charStyles: charStyles,
          type: post.type,
          filePath: post.filePath,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
        );
      }
      return post;
    }).toList();
  }

  /// Toggles the saved status of a social post.
  void toggleSavedSocialPost(String postId) {
    final current = Set<String>.from(savedSocialPostIds);
    bool isSaved = false;
    if (current.contains(postId)) {
      current.remove(postId);
    } else {
      current.add(postId);
      isSaved = true;
    }
    savedSocialPostIdsNotifier.value = current;

    if (isSaved) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'saved',
        postTitle: details['title']!,
        author: details['author']!,
      );
    }
  }

  /// The predefined posts imported from the Figma mock designs.
  static final List<PostModel> predefinedPosts = [
    const PostModel(
      id: 'welcome-post',
      mediaAssetPath: 'assets/images/app_logo_memoria.png',
      likesCount: 0,
      savesCount: 0,
      sharesCount: 0,
      cardHeight: 180,
      title: 'Welcome to Memoria!',
      username: 'memoria_team',
      avatarAssetPath: null,
      description: 'Your feed is currently empty. Start by posting something or saving an item to your profile!',
      url: null,
    ),
  ];
}
