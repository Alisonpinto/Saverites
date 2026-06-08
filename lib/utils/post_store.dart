import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'rich_text_controller.dart';

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
      ValueNotifier<Set<String>>({
    'social-1',
    'social-2',
    'social-3',
    'social-4',
    'social-5',
    'social-6',
  });

  Set<String> get savedSocialPostIds => savedSocialPostIdsNotifier.value;

  /// Set of liked post IDs.
  final ValueNotifier<Set<String>> likedPostIdsNotifier =
      ValueNotifier<Set<String>>({});

  Set<String> get likedPostIds => likedPostIdsNotifier.value;

  /// Toggles the liked status of a post.
  void toggleLikedPost(String postId) {
    final current = Set<String>.from(likedPostIds);
    if (current.contains(postId)) {
      current.remove(postId);
    } else {
      current.add(postId);
    }
    likedPostIdsNotifier.value = current;
  }

  /// Adds a post and notifies all listeners.
  void addPost(UserPost post) {
    postsNotifier.value = [post, ...postsNotifier.value];
  }

  /// Toggles the savedInProfile status of a post and notifies listeners.
  void toggleSavedInProfile(String postId) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (post.id == postId) {
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
        );
      }
      return post;
    }).toList();
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
        );
      }
      return post;
    }).toList();
  }

  /// Toggles the saved status of a social post.
  void toggleSavedSocialPost(String postId) {
    final current = Set<String>.from(savedSocialPostIds);
    if (current.contains(postId)) {
      current.remove(postId);
    } else {
      current.add(postId);
    }
    savedSocialPostIdsNotifier.value = current;
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
      likesCount: 1000,
      savesCount: 1300,
      sharesCount: 100,
      cardHeight: 150,
      title: 'CLASSIC CHIC JACKET',
      username: 'jawaan_ki_girlfriend',
      avatarAssetPath: 'assets/images/google_logo.png',
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
