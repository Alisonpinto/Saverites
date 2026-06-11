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
      id: 'social-1',
      mediaAssetPath: 'assets/images/outfit.png',
      likesCount: 1000,
      savesCount: 1300,
      sharesCount: 100,
      cardHeight: 270,
      title: 'Trend Huntss',
      username: 'jawaan_ki_girlfriend',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'hey i want you to tell antigravity to make the profile page like this something Basically I want you to write me a good prompt to tell anti gravity to make the profile section g a',
      url: 'https://trendhuntss.com',
    ),
    const PostModel(
      id: 'social-2',
      mediaAssetPath: 'assets/images/jacket.png',
      likesCount: 6000,
      savesCount: 9000,
      sharesCount: 100,
      cardHeight: 250,
      title: 'check out my new...',
      username: 'jawaan_ki_chokri',
      avatarAssetPath: null,
      description: 'A premium neutral-toned utility jacket, perfect for transitional styling. Fits true to size with custom hardware details.',
      url: 'https://memoria.app/shop/jacket',
    ),
    const PostModel(
      id: 'social-3',
      mediaAssetPath: 'assets/images/meme.png',
      likesCount: 1000,
      savesCount: 1300,
      sharesCount: 100,
      cardHeight: 210,
      title: 'REKHA JI GOOGLE SEARCH',
      username: 'memer_king',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'When you search for nostalgic icons and Google results are not so sanskari. Peak internet humor.',
      url: 'https://google.com/search?q=rekha',
    ),
    const PostModel(
      id: 'social-4',
      mediaAssetPath: 'assets/images/panda.png',
      likesCount: 1000,
      savesCount: 1300,
      sharesCount: 100,
      cardHeight: 250,
      title: 'PEACE BRO!',
      username: 'chill_panda',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'A chill panda illustration with a reminder to take a break and find your inner peace.',
      url: 'https://memoria.app/panda',
      accentColor: Color(0xFFE52E5E),
    ),
    const PostModel(
      id: 'social-5',
      mediaAssetPath: 'assets/images/jacket.png',
      likesCount: 1200,
      savesCount: 850,
      sharesCount: 45,
      cardHeight: 150,
      title: 'URBAN JACKET STYLE',
      username: 'jawaan_ki_girlfriend',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'Another look at the urban utility jacket in studio light. High premium quality fabric.',
      url: 'https://memoria.app/shop/jacket-2',
    ),
    const PostModel(
      id: 'social-6',
      mediaAssetPath: 'assets/images/panda.png',
      likesCount: 920,
      savesCount: 1100,
      sharesCount: 60,
      cardHeight: 250,
      title: 'CHILL TIME',
      username: 'chill_panda',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'Just chill. Relaxing is productive too. Take a moment for yourself.',
      url: 'https://memoria.app/chill',
      accentColor: Color(0xFF00B0FF),
    ),
    const PostModel(
      id: 'social-7',
      mediaAssetPath: 'assets/images/meme.png',
      likesCount: 800,
      savesCount: 500,
      sharesCount: 25,
      cardHeight: 210,
      title: 'PROFESSIONAL FLUTTER LOOKS',
      username: 'flutter_dev',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'Making your Flutter app look professional in 5 minutes. The ultimate developer hack.',
      url: 'https://flutter.dev',
    ),
    const PostModel(
      id: 'social-8',
      mediaAssetPath: 'assets/images/outfit.png',
      likesCount: 1500,
      savesCount: 2000,
      sharesCount: 180,
      cardHeight: 270,
      title: 'STREET STYLE 2026',
      username: 'street_style_co',
      avatarAssetPath: 'assets/images/google_logo.png',
      description: 'Exploring minimalism and neutral tones in street fashion. Ralph Lauren polo sweater styled with beige pleated trousers.',
      url: 'https://streetstyle.com',
    ),
  ];
}
