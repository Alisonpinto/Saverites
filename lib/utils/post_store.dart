import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import 'rich_text_controller.dart';
import 'notification_manager.dart';

/// A single user-created post (text + optional media file path).
class UserPost {
  final String id;
  final String title;
  final String body;
  final String? url;
  final String? username; // The user who created the post

  /// Absolute path to a local image file, or null if no image attached.
  String? imagePath;

  /// Absolute path to a local video file, or null if no video attached.
  String? videoPath;

  /// Whether to also save this post in the profile grid.
  final bool savedInProfile;

  /// Whether this post is hidden in the Locked Folder.
  final bool isLocked;

  final DateTime createdAt;

  /// Formatting character-by-character styles.
  final List<RichStyle>? charStyles;

  // New fields for Save to Memoria workflow:
  final String? type;            // "image", "video", "document", "audio", "contact", "link", "text", "checklist", "code"
  String? filePath;        // local file path for document/audio/vcf
  final List<String>? filePaths; // multiple local file paths for documents
  final String? contactName;     // contact full name
  final String? contactPhone;    // contact phone number
  final List<String>? contactNames;
  final List<String>? contactPhones;
  final String? duration;        // audio duration
  final List<String>? checklistItems; // checklist entries
  final List<bool>? checklistStates;  // checkbox states

  final String? imageBase64;
  final String? videoBase64;
  final String? fileBase64;
  final List<String>? fileBase64s;

  UserPost({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    this.username,
    this.imagePath,
    this.videoPath,
    required this.savedInProfile,
    this.isLocked = false,
    required this.createdAt,
    this.charStyles,
    this.type,
    this.filePath,
    this.filePaths,
    this.contactName,
    this.contactPhone,
    this.contactNames,
    this.contactPhones,
    this.duration,
    this.checklistItems,
    this.checklistStates,
    this.imageBase64,
    this.videoBase64,
    this.fileBase64,
    this.fileBase64s,
  });

  Map<String, dynamic> toJson() {
    String? imgB64 = imageBase64;
    if (!kIsWeb && imgB64 == null && imagePath != null) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        try {
          imgB64 = base64Encode(file.readAsBytesSync());
        } catch (e) {
          debugPrint("Error reading image bytes: $e");
        }
      }
    }
    String? vidB64 = videoBase64;
    if (!kIsWeb && vidB64 == null && videoPath != null) {
      final file = File(videoPath!);
      if (file.existsSync()) {
        try {
          vidB64 = base64Encode(file.readAsBytesSync());
        } catch (e) {
          debugPrint("Error reading video bytes: $e");
        }
      }
    }
    String? fileB64Val = fileBase64;
    if (!kIsWeb && fileB64Val == null && filePath != null) {
      final file = File(filePath!);
      if (file.existsSync()) {
        try {
          fileB64Val = base64Encode(file.readAsBytesSync());
        } catch (e) {
          debugPrint("Error reading file bytes: $e");
        }
      }
    }

    List<String>? fileB64sVals = fileBase64s;
    if (!kIsWeb && fileB64sVals == null && filePaths != null) {
      fileB64sVals = [];
      for (var fp in filePaths!) {
        final file = File(fp);
        if (file.existsSync()) {
          try {
            fileB64sVals.add(base64Encode(file.readAsBytesSync()));
          } catch (e) {
            debugPrint("Error reading file bytes for list: $e");
          }
        }
      }
    }

    return {
      'id': id,
      'title': title,
      'body': body,
      'url': url,
      'username': username,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'savedInProfile': savedInProfile,
      'isLocked': isLocked,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'charStyles': charStyles?.map((s) => s.toJson()).toList(),
      'type': type,
      'filePath': filePath,
      'filePaths': filePaths,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactNames': contactNames,
      'contactPhones': contactPhones,
      'duration': duration,
      'checklistItems': checklistItems,
      'checklistStates': checklistStates,
      'imageBase64': imgB64,
      'videoBase64': vidB64,
      'fileBase64': fileB64Val,
      'fileBase64s': fileB64sVals,
    };
  }

  factory UserPost.fromJson(Map<String, dynamic> json) {
    String? imagePath = json['imagePath'] as String?;
    String? videoPath = json['videoPath'] as String?;
    String? filePath = json['filePath'] as String?;
    List<String>? filePaths = (json['filePaths'] as List?)?.cast<String>();

    final imgB64 = json['imageBase64'] as String?;
    if (!kIsWeb && imgB64 != null) {
      try {
        final filename = 'img_${json['id']}.png';
        final tempFile = File('${Directory.systemTemp.path}/$filename');
        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          tempFile.writeAsBytesSync(base64Decode(imgB64));
        }
        imagePath = tempFile.path;
      } catch (e) {
        debugPrint("Error recreating image from base64: $e");
      }
    }

    final vidB64 = json['videoBase64'] as String?;
    if (!kIsWeb && vidB64 != null) {
      try {
        final filename = 'vid_${json['id']}.mp4';
        final tempFile = File('${Directory.systemTemp.path}/$filename');
        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          tempFile.writeAsBytesSync(base64Decode(vidB64));
        }
        videoPath = tempFile.path;
      } catch (e) {
        debugPrint("Error recreating video from base64: $e");
      }
    }

    final fileB64Val = json['fileBase64'] as String?;
    if (!kIsWeb && fileB64Val != null) {
      try {
        final ext = (json['type'] as String?) == 'document' ? 'pdf' : 'bin';
        final filename = 'file_${json['id']}.$ext';
        final tempFile = File('${Directory.systemTemp.path}/$filename');
        if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
          tempFile.writeAsBytesSync(base64Decode(fileB64Val));
        }
        filePath = tempFile.path;
      } catch (e) {
        debugPrint("Error recreating file from base64: $e");
      }
    }

    final fileB64sVals = (json['fileBase64s'] as List?)?.cast<String>();
    if (!kIsWeb && fileB64sVals != null) {
      filePaths = [];
      for (int i = 0; i < fileB64sVals.length; i++) {
        try {
          final ext = (json['type'] as String?) == 'document' ? 'pdf' : 'bin';
          final filename = 'file_${json['id']}_$i.$ext';
          final tempFile = File('${Directory.systemTemp.path}/$filename');
          if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
            tempFile.writeAsBytesSync(base64Decode(fileB64sVals[i]));
          }
          filePaths.add(tempFile.path);
        } catch (e) {
          debugPrint("Error recreating file from base64 list: $e");
        }
      }
    }

    return UserPost(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      url: json['url'] as String?,
      username: json['username'] as String?,
      imagePath: imagePath,
      videoPath: videoPath,
      savedInProfile: json['savedInProfile'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      charStyles: (json['charStyles'] as List?)
          ?.map((s) => RichStyle.fromJson(s as Map<String, dynamic>))
          .toList(),
      type: json['type'] as String?,
      filePath: filePath,
      filePaths: filePaths,
      contactName: json['contactName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactNames: (json['contactNames'] as List?)?.cast<String>(),
      contactPhones: (json['contactPhones'] as List?)?.cast<String>(),
      duration: json['duration'] as String?,
      checklistItems: (json['checklistItems'] as List?)?.cast<String>(),
      checklistStates: (json['checklistStates'] as List?)?.cast<bool>(),
      imageBase64: imgB64,
      videoBase64: vidB64,
      fileBase64: fileB64Val,
      fileBase64s: fileB64sVals,
    );
  }
}

/// Global reactive store for user-created posts.
///
/// Both [FeedScreen] and [ProfileScreen] listen to [postsNotifier]
/// so that when the user posts, both update simultaneously.
class PostStore {
  PostStore._();
  static final PostStore instance = PostStore._();

  static const String _kvdbUrl = 'https://jsonblob.com/api/jsonBlob/019ed7cb-fda2-716d-b43c-b868d304b6fd';

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

  /// Set of hidden post IDs.
  final ValueNotifier<Set<String>> hiddenPostIdsNotifier =
      ValueNotifier<Set<String>>({});

  Set<String> get hiddenPostIds => hiddenPostIdsNotifier.value;

  Future<void> loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load liked IDs
      final likedList = prefs.getStringList('liked_post_ids');
      if (likedList != null) {
        likedPostIdsNotifier.value = likedList.toSet();
      }

      // Load saved social IDs
      final savedSocialList = prefs.getStringList('saved_social_post_ids');
      if (savedSocialList != null) {
        savedSocialPostIdsNotifier.value = savedSocialList.toSet();
      }

      // Load hidden post IDs
      final hiddenList = prefs.getStringList('hidden_post_ids');
      if (hiddenList != null) {
        hiddenPostIdsNotifier.value = hiddenList.toSet();
      }

      // Load user posts
      final postsJson = prefs.getString('user_posts');
      if (postsJson != null) {
        final decoded = jsonDecode(postsJson);
        if (decoded is List) {
          final List<UserPost> loaded = [];
          for (var p in decoded) {
            try {
              loaded.add(UserPost.fromJson(p as Map<String, dynamic>));
            } catch (e) {
              debugPrint("Error parsing local post: $e");
            }
          }
          postsNotifier.value = loaded;
        }
      }
    } catch (e) {
      debugPrint("Error loading from local: $e");
    }
  }

  Future<void> saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('liked_post_ids', likedPostIds.toList());
      await prefs.setStringList('saved_social_post_ids', savedSocialPostIds.toList());
      await prefs.setStringList('hidden_post_ids', hiddenPostIds.toList());

      final postsJson = jsonEncode(postsNotifier.value.map((p) => p.toJson()).toList());
      await prefs.setString('user_posts', postsJson);
    } catch (e) {
      debugPrint("Error saving to local: $e");
    }
  }

  Future<void> syncOnlinePosts() async {
    try {
      final response = await http.get(Uri.parse(_kvdbUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final List<UserPost> onlinePosts = [];
          for (var p in decoded) {
            try {
              onlinePosts.add(UserPost.fromJson(p as Map<String, dynamic>));
            } catch (e) {
              debugPrint("Error parsing online post: $e");
            }
          }

          // Merge with local posts:
          // Keep local private posts (savedInProfile == true)
          // Merge local public posts with online public posts (matching by ID)
          final List<UserPost> currentPosts = List.from(postsNotifier.value);
          final privatePosts = currentPosts.where((p) => p.savedInProfile).toList();

          final Map<String, UserPost> mergedMap = {};
          // First add online posts
          for (var p in onlinePosts) {
            mergedMap[p.id] = p;
          }
          // Then add current posts (so local public additions are preserved)
          for (var p in currentPosts) {
            if (!p.savedInProfile) {
              mergedMap[p.id] = p;
            }
          }

          // Combine private and merged public posts
          final List<UserPost> finalPosts = [
            ...privatePosts,
            ...mergedMap.values.where((p) => !p.savedInProfile)
          ];

          // Sort by createdAt descending
          finalPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // Only update if something actually changed (avoid unnecessary rebuilds)
          final currentIds = postsNotifier.value.map((p) => p.id).toList();
          final finalIds = finalPosts.map((p) => p.id).toList();
          if (currentIds.length != finalIds.length || !currentIds.every((id) => finalIds.contains(id))) {
            postsNotifier.value = finalPosts;
            await saveToLocal();
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing online posts: $e");
    }
  }

  Future<void> uploadPostOnline(UserPost newPost) async {
    try {
      // 1. Get latest online posts (with short timeout for speed)
      List<dynamic> jsonList = [];
      bool fetchSuccess = false;
      try {
        final response = await http.get(Uri.parse(_kvdbUrl)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          if (decoded is List) {
            jsonList = decoded;
            fetchSuccess = true;
          }
        }
      } catch (e) {
        debugPrint("Error fetching online posts for upload: $e");
      }

      if (!fetchSuccess && jsonList.isEmpty) {
        // If we failed to fetch the list and it's completely empty, abort so we don't wipe existing posts
        debugPrint("Aborting upload because fetching the current list failed");
        return;
      }

      // 2. Prepend our new post. Keep base64 data intact so that
      // other users can download and view media files properly.
      final postMap = newPost.toJson();
      
      jsonList.insert(0, postMap);

      // 3. Write back with a reasonable timeout
      final putResponse = await http.put(
        Uri.parse(_kvdbUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonList),
      ).timeout(const Duration(seconds: 15));

      if (putResponse.statusCode != 200 && putResponse.statusCode != 201) {
        debugPrint("Failed to upload: ${putResponse.statusCode} ${putResponse.body}");
      } else {
        debugPrint("Post uploaded successfully.");
      }
    } catch (e) {
      debugPrint("Error uploading post online: $e");
    }
  }

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
    saveToLocal();

    if (isLiked) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'liked',
        postTitle: details['title']!,
        author: details['author']!,
      );
    }
  }

  /// Hides a post so it no longer appears in the feed.
  void hidePost(String postId) {
    final current = Set<String>.from(hiddenPostIds);
    current.add(postId);
    hiddenPostIdsNotifier.value = current;
    saveToLocal();
  }

  /// Unhides a previously hidden post.
  void unhidePost(String postId) {
    final current = Set<String>.from(hiddenPostIds);
    current.remove(postId);
    hiddenPostIdsNotifier.value = current;
    saveToLocal();
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
        return {'title': p.title, 'author': p.username ?? 'You'};
      }
    }
    return {'title': 'Untitled Post', 'author': 'someone'};
  }

  /// Adds a post and notifies all listeners.
  void addPost(UserPost post) {
    postsNotifier.value = [post, ...postsNotifier.value];
    saveToLocal();

    if (!post.savedInProfile) {
      uploadPostOnline(post);
    }

    if (post.savedInProfile) {
      NotificationManager.instance.triggerVaultReminderNotification(post.title);
    } else {
      savedSocialPostIdsNotifier.value = {post.id, ...savedSocialPostIdsNotifier.value};
      saveToLocal();
    }
  }

  /// Updates an existing post and notifies all listeners.
  void updateUserPost(UserPost updatedPost) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (post.id == updatedPost.id) {
        return updatedPost;
      }
      return post;
    }).toList();
    saveToLocal();
  }

  /// Removes multiple posts by ID and notifies all listeners.
  void removeUserPosts(Set<String> postIds) {
    postsNotifier.value = postsNotifier.value.where((post) => !postIds.contains(post.id)).toList();
    saveToLocal();
  }

  /// Locks multiple posts by ID and notifies all listeners.
  void lockUserPosts(Set<String> postIds) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (postIds.contains(post.id)) {
        return UserPost(
          id: post.id,
          title: post.title,
          body: post.body,
          url: post.url,
          username: post.username,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: post.savedInProfile,
          isLocked: true,
          createdAt: post.createdAt,
          charStyles: post.charStyles,
          type: post.type,
          filePath: post.filePath,
          filePaths: post.filePaths,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          contactNames: post.contactNames,
          contactPhones: post.contactPhones,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
          imageBase64: post.imageBase64,
          videoBase64: post.videoBase64,
          fileBase64: post.fileBase64,
          fileBase64s: post.fileBase64s,
        );
      }
      return post;
    }).toList();
    saveToLocal();
  }

  /// Unlocks multiple posts by ID and notifies all listeners.
  void unlockUserPosts(Set<String> postIds) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (postIds.contains(post.id)) {
        return UserPost(
          id: post.id,
          title: post.title,
          body: post.body,
          url: post.url,
          username: post.username,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: post.savedInProfile,
          isLocked: false,
          createdAt: post.createdAt,
          charStyles: post.charStyles,
          type: post.type,
          filePath: post.filePath,
          filePaths: post.filePaths,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          contactNames: post.contactNames,
          contactPhones: post.contactPhones,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
          imageBase64: post.imageBase64,
          videoBase64: post.videoBase64,
          fileBase64: post.fileBase64,
          fileBase64s: post.fileBase64s,
        );
      }
      return post;
    }).toList();
    saveToLocal();
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
          username: post.username,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: !post.savedInProfile,
          createdAt: post.createdAt,
          charStyles: post.charStyles,
          type: post.type,
          filePath: post.filePath,
          filePaths: post.filePaths,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          contactNames: post.contactNames,
          contactPhones: post.contactPhones,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
          imageBase64: post.imageBase64,
          videoBase64: post.videoBase64,
          fileBase64: post.fileBase64,
          fileBase64s: post.fileBase64s,
        );
      }
      return post;
    }).toList();
    saveToLocal();

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
          username: post.username,
          imagePath: post.imagePath,
          videoPath: post.videoPath,
          savedInProfile: post.savedInProfile,
          createdAt: post.createdAt,
          charStyles: charStyles,
          type: post.type,
          filePath: post.filePath,
          filePaths: post.filePaths,
          contactName: post.contactName,
          contactPhone: post.contactPhone,
          contactNames: post.contactNames,
          contactPhones: post.contactPhones,
          duration: post.duration,
          checklistItems: post.checklistItems,
          checklistStates: post.checklistStates,
          imageBase64: post.imageBase64,
          videoBase64: post.videoBase64,
          fileBase64: post.fileBase64,
          fileBase64s: post.fileBase64s,
        );
      }
      return post;
    }).toList();
    saveToLocal();
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
    saveToLocal();

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
      mediaAssetPath: 'assets/images/logo.jpeg',
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
