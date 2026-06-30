import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../widgets/dice_avatar.dart';
import 'rich_text_controller.dart';
import 'notification_manager.dart';
import 'user_store.dart';

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

  /// Whether this post is only visible to friends (not public to all).
  final bool isPrivate;

  /// Whether this post is hidden in the Locked Folder.
  final bool isLocked;

  final DateTime createdAt;

  /// Formatting character-by-character styles.
  final List<RichStyle>? charStyles;

  // New fields for Save to Memoria workflow:
  final String?
  type; // "image", "video", "document", "audio", "contact", "link", "text", "checklist", "code"
  String? filePath; // local file path for document/audio/vcf
  final List<String>? filePaths; // multiple local file paths for documents
  final String? contactName; // contact full name
  final String? contactPhone; // contact phone number
  final List<String>? contactNames;
  final List<String>? contactPhones;
  final String? duration; // audio duration
  final List<String>? checklistItems; // checklist entries
  final List<bool>? checklistStates; // checkbox states

  final String? imageBase64;
  final String? videoBase64;
  final String? fileBase64;
  final List<String>? fileBase64s;

  // Supabase storage URLs
  final String? imageUrl;
  final String? videoUrl;
  final String? fileUrl;
  final List<String>? fileUrls;

  UserPost({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    this.username,
    this.imagePath,
    this.videoPath,
    required this.savedInProfile,
    this.isPrivate = false,
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
    this.imageUrl,
    this.videoUrl,
    this.fileUrl,
    this.fileUrls,
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
      'is_private': isPrivate,
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
      'image_url': imageUrl,
      'video_url': videoUrl,
      'file_url': fileUrl,
      'file_urls': fileUrls,
    };
  }

  static final Map<String, Future<void>> _activeDownloads = {};

  static void _downloadFile(String url, File targetFile, String postId, String field) {
    final key = '$postId-$field';
    if (_activeDownloads.containsKey(key)) return;

    final future = Future(() async {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(resp.bodyBytes);
          
          final store = PostStore.instance;
          final updatedList = store.postsNotifier.value.map((post) {
            if (post.id == postId) {
              return post.copyWithField(field, targetFile.path);
            }
            return post;
          }).toList();
          store.postsNotifier.value = updatedList;
        }
      } catch (e) {
        debugPrint('Error downloading media $url: $e');
      }
    });

    _activeDownloads[key] = future;
    future.whenComplete(() => _activeDownloads.remove(key));
  }

  UserPost copyWithField(String field, String path) {
    return UserPost(
      id: id,
      title: title,
      body: body,
      url: url,
      username: username,
      imagePath: field == 'imagePath' ? path : imagePath,
      videoPath: field == 'videoPath' ? path : videoPath,
      savedInProfile: savedInProfile,
      isPrivate: isPrivate,
      isLocked: isLocked,
      createdAt: createdAt,
      charStyles: charStyles,
      type: type,
      filePath: field == 'filePath' ? path : filePath,
      filePaths: field == 'filePaths' ? [path] : filePaths,
      contactName: contactName,
      contactPhone: contactPhone,
      contactNames: contactNames,
      contactPhones: contactPhones,
      duration: duration,
      checklistItems: checklistItems,
      checklistStates: checklistStates,
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      fileUrl: fileUrl,
      fileUrls: fileUrls,
    );
  }

  factory UserPost.fromJson(Map<String, dynamic> json) {
    try {
      String? imagePath = json['imagePath'] as String?;
      String? videoPath = json['videoPath'] as String?;
      String? filePath = json['filePath'] as String?;
      List<String>? filePaths = json['filePaths'] != null 
          ? List<String>.from(json['filePaths'] as Iterable) 
          : null;

      final imgUrl = json['image_url'] as String?;
      final vidUrl = json['video_url'] as String?;
      final filUrl = json['file_url'] as String?;
      final filUrls = json['file_urls'] != null 
          ? List<String>.from(json['file_urls'] as Iterable) 
          : null;

      final id = json['id']?.toString() ?? '';

      // Resolve or download network URLs if local paths are not available
      if (imgUrl != null && imgUrl.isNotEmpty) {
        final ext = imgUrl.split('.').last.split('?').first;
        final tempFile = File('${Directory.systemTemp.path}/img_$id.$ext');
        if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
          imagePath = tempFile.path;
        } else {
          _downloadFile(imgUrl, tempFile, id, 'imagePath');
        }
      }

      if (vidUrl != null && vidUrl.isNotEmpty) {
        final ext = vidUrl.split('.').last.split('?').first;
        final tempFile = File('${Directory.systemTemp.path}/vid_$id.$ext');
        if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
          videoPath = tempFile.path;
        } else {
          _downloadFile(vidUrl, tempFile, id, 'videoPath');
        }
      }

      if (filUrl != null && filUrl.isNotEmpty) {
        final ext = filUrl.split('.').last.split('?').first;
        final tempFile = File('${Directory.systemTemp.path}/file_$id.$ext');
        if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
          filePath = tempFile.path;
        } else {
          _downloadFile(filUrl, tempFile, id, 'filePath');
        }
      }

      // Support legacy base64 format fallback
      if (imagePath == null || imagePath.isEmpty) {
        final imgB64 = json['imageBase64'] as String?;
        if (!kIsWeb && imgB64 != null) {
          try {
            final filename = 'img_$id.png';
            final tempFile = File('${Directory.systemTemp.path}/$filename');
            if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
              tempFile.writeAsBytesSync(base64Decode(imgB64));
            }
            imagePath = tempFile.path;
          } catch (e) {
            debugPrint("Error recreating image from base64: $e");
          }
        }
      }

      if (videoPath == null || videoPath.isEmpty) {
        final vidB64 = json['videoBase64'] as String?;
        if (!kIsWeb && vidB64 != null) {
          try {
            final filename = 'vid_$id.mp4';
            final tempFile = File('${Directory.systemTemp.path}/$filename');
            if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
              tempFile.writeAsBytesSync(base64Decode(vidB64));
            }
            videoPath = tempFile.path;
          } catch (e) {
            debugPrint("Error recreating video from base64: $e");
          }
        }
      }

      if (filePath == null || filePath.isEmpty) {
        final fileB64Val = json['fileBase64'] as String?;
        if (!kIsWeb && fileB64Val != null) {
          try {
            final ext = (json['type'] as String?) == 'document' ? 'pdf' : 'bin';
            final filename = 'file_$id.$ext';
            final tempFile = File('${Directory.systemTemp.path}/$filename');
            if (!tempFile.existsSync() || tempFile.lengthSync() == 0) {
              tempFile.writeAsBytesSync(base64Decode(fileB64Val));
            }
            filePath = tempFile.path;
          } catch (e) {
            debugPrint("Error recreating file from base64: $e");
          }
        }
      }

      final fileB64sVals = json['fileBase64s'] != null 
          ? List<String>.from(json['fileBase64s'] as Iterable) 
          : null;
      if (!kIsWeb && fileB64sVals != null && (filePaths == null || filePaths.isEmpty)) {
        filePaths = [];
        for (int i = 0; i < fileB64sVals.length; i++) {
          try {
            final ext = (json['type'] as String?) == 'document' ? 'pdf' : 'bin';
            final filename = 'file_${id}_$i.$ext';
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

      final dynamic rawCreatedAt = json['createdAt'] ?? json['created_at'];
      DateTime parsedDate;
      if (rawCreatedAt is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt);
      } else if (rawCreatedAt is String) {
        parsedDate = DateTime.parse(rawCreatedAt);
      } else {
        parsedDate = DateTime.now();
      }

      final rawCharStyles = json['charStyles'] ?? json['char_styles'];
      List<RichStyle>? parsedCharStyles;
      if (rawCharStyles is List) {
        parsedCharStyles = rawCharStyles
            .map((s) => RichStyle.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
      }

      final rawContactNames = json['contactNames'] ?? json['contact_names'];
      final rawContactPhones = json['contactPhones'] ?? json['contact_phones'];
      final rawChecklistItems = json['checklistItems'] ?? json['checklist_items'];
      final rawChecklistStates = json['checklistStates'] ?? json['checklist_states'];

      return UserPost(
        id: id,
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        url: json['url']?.toString(),
        username: json['username']?.toString() ?? json['user_id']?.toString(),
        imagePath: imagePath,
        videoPath: videoPath,
        savedInProfile: json['savedInProfile'] ?? json['saved_in_profile'] ?? false,
        isPrivate: json['isPrivate'] ?? json['is_private'] ?? false,
        isLocked: json['isLocked'] ?? json['is_locked'] ?? false,
        createdAt: parsedDate,
        charStyles: parsedCharStyles,
        type: json['type']?.toString(),
        filePath: filePath,
        filePaths: filePaths,
        contactName: json['contactName']?.toString(),
        contactPhone: json['contactPhone']?.toString(),
        contactNames: rawContactNames != null ? List<String>.from(rawContactNames as Iterable) : null,
        contactPhones: rawContactPhones != null ? List<String>.from(rawContactPhones as Iterable) : null,
        duration: json['duration']?.toString(),
        checklistItems: rawChecklistItems != null ? List<String>.from(rawChecklistItems as Iterable) : null,
        checklistStates: rawChecklistStates != null ? List<bool>.from(rawChecklistStates as Iterable) : null,
        imageBase64: json['imageBase64']?.toString(),
        videoBase64: json['videoBase64']?.toString(),
        fileBase64: json['fileBase64']?.toString(),
        fileBase64s: json['fileBase64s'] != null ? List<String>.from(json['fileBase64s'] as Iterable) : null,
        imageUrl: imgUrl,
        videoUrl: vidUrl,
        fileUrl: filUrl,
        fileUrls: filUrls,
      );
    } catch (e, stack) {
      debugPrint("CRITICAL ERROR parsing UserPost.fromJson: $e\n$stack");
      rethrow;
    }
  }
}

/// Global reactive store for user-created posts.
class PostStore {
  PostStore._();
  static final PostStore instance = PostStore._();

  final Set<String> _pendingUploadIds = {};

  /// All published posts, newest first.
  final ValueNotifier<List<UserPost>> postsNotifier =
      ValueNotifier<List<UserPost>>([]);

  List<UserPost> get posts => postsNotifier.value;

  /// Map of postId -> list of comments
  final ValueNotifier<Map<String, List<CommentModel>>> commentsNotifier =
      ValueNotifier<Map<String, List<CommentModel>>>({});

  Map<String, List<CommentModel>> get comments => commentsNotifier.value;

  /// Map of postId -> count of likes
  final ValueNotifier<Map<String, int>> postLikesCountNotifier =
      ValueNotifier<Map<String, int>>({});

  Map<String, int> get postLikesCount => postLikesCountNotifier.value;

  Timer? _syncTimer;
  RealtimeChannel? _postsChannel;
  RealtimeChannel? _commentsChannel;
  RealtimeChannel? _likesChannel;

  void startSyncTimer() {
    if (_syncTimer != null) return;
    // Poll every 30s as a fallback — realtime subscription handles instant updates
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncOnlinePosts();
    });
  }

  /// Subscribe to Supabase Realtime for instant post updates.
  void subscribeToPostUpdates() {
    if (_postsChannel != null) return;

    _postsChannel = Supabase.instance.client
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'posts',
          callback: (payload) async {
            try {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final record = payload.newRecord;

                // Skip items saved only in profile (personal saves, not social)
                final savedInProfile = record['saved_in_profile'] as bool? ?? false;
                if (savedInProfile) return;

                // is_private is optional — column may not exist yet in Supabase
                final isPrivatePost = record['is_private'] as bool? ?? false;
                final postAuthorUserId = record['user_id']?.toString() ?? '';
                final currentUuid = Supabase.instance.client.auth.currentUser?.id;

                if (isPrivatePost && currentUuid != null) {
                  // Private post: only show if the current user follows this author
                  final currentUserHandle = UserStore.instance.currentUser?.userId;
                  // Own post — always show
                  if (postAuthorUserId != currentUuid && postAuthorUserId != currentUserHandle) {
                    // Check if the current user follows this author
                    final followCheck = await Supabase.instance.client
                        .from('user_follows')
                        .select('followed_id')
                        .eq('follower_id', currentUuid)
                        .eq('followed_id', postAuthorUserId)
                        .maybeSingle();
                    if (followCheck == null) return; // not a friend, skip
                  }
                }

                final newPost = UserPost.fromJson(record);
                final currentIds = postsNotifier.value.map((p) => p.id).toSet();
                if (!currentIds.contains(newPost.id)) {
                  postsNotifier.value = [newPost, ...postsNotifier.value];
                  debugPrint('Realtime Post Insert: ${newPost.id}');
                }
              } else if (payload.eventType == PostgresChangeEvent.update) {
                final record = payload.newRecord;
                final updatedPost = UserPost.fromJson(record);
                postsNotifier.value = postsNotifier.value.map((p) {
                  return p.id == updatedPost.id ? updatedPost : p;
                }).toList();
                debugPrint('Realtime Post Update: ${updatedPost.id}');
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final record = payload.oldRecord;
                final deletedId = record['id']?.toString();
                if (deletedId != null) {
                  postsNotifier.value = postsNotifier.value.where((p) => p.id != deletedId).toList();
                  debugPrint('Realtime Post Delete: $deletedId');
                }
              }
            } catch (e) {
              debugPrint('Error processing realtime post event: $e');
            }
          },
        );
    _postsChannel!.subscribe();

    if (_commentsChannel == null) {
      _commentsChannel = Supabase.instance.client
          .channel('public:post_comments')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'post_comments',
            callback: (payload) {
              try {
                if (payload.eventType == PostgresChangeEvent.insert) {
                  final record = payload.newRecord;
                  final newComment = CommentModel.fromJson(record);
                  
                  final current = Map<String, List<CommentModel>>.from(commentsNotifier.value);
                  final postId = newComment.postId;
                  
                  final list = current[postId] ?? [];
                  // Prevent duplicates
                  if (!list.any((c) => c.id == newComment.id)) {
                    current[postId] = [...list, newComment];
                    commentsNotifier.value = current;
                    debugPrint('Realtime Comment Insert for post $postId: ${newComment.id}');
                  }
                } else if (payload.eventType == PostgresChangeEvent.update) {
                  final record = payload.newRecord;
                  final updatedComment = CommentModel.fromJson(record);
                  
                  final current = Map<String, List<CommentModel>>.from(commentsNotifier.value);
                  final postId = updatedComment.postId;
                  
                  final list = current[postId] ?? [];
                  current[postId] = list.map((c) {
                    return c.id == updatedComment.id ? updatedComment : c;
                  }).toList();
                  commentsNotifier.value = current;
                  debugPrint('Realtime Comment Update for post $postId: ${updatedComment.id}');
                } else if (payload.eventType == PostgresChangeEvent.delete) {
                  final record = payload.oldRecord;
                  final deletedId = record['id']?.toString();
                  if (deletedId != null) {
                    final current = Map<String, List<CommentModel>>.from(commentsNotifier.value);
                    for (final postId in current.keys) {
                      final list = current[postId] ?? [];
                      if (list.any((c) => c.id == deletedId)) {
                        current[postId] = list.where((c) => c.id != deletedId).toList();
                      }
                    }
                    commentsNotifier.value = current;
                    debugPrint('Realtime Comment Delete: $deletedId');
                  }
                }
              } catch (e) {
                debugPrint('Error processing realtime comment event: $e');
              }
            },
          );
      _commentsChannel!.subscribe();
    }

    if (_likesChannel == null) {
      _likesChannel = Supabase.instance.client
          .channel('public:post_likes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'post_likes',
            callback: (payload) {
              debugPrint('Realtime post_likes event: ${payload.eventType}. Syncing likes...');
              syncLikes();
            },
          );
      _likesChannel!.subscribe();
    }
  }

  /// Cancel realtime subscription and timers.
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
    _postsChannel?.unsubscribe();
    _postsChannel = null;
    _commentsChannel?.unsubscribe();
    _commentsChannel = null;
    _likesChannel?.unsubscribe();
    _likesChannel = null;
  }

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

  Future<void> init() async {
    await loadFromLocal();
    await loadCommentsFromLocal();
    UserStore.instance.currentUserNotifier.addListener(() {
      syncOnlinePosts();
      // Re-subscribe on user change (login/logout)
      _postsChannel?.unsubscribe();
      _postsChannel = null;
      _commentsChannel?.unsubscribe();
      _commentsChannel = null;
      _likesChannel?.unsubscribe();
      _likesChannel = null;
      subscribeToPostUpdates();
    });
    await syncOnlinePosts(); // sync immediately on startup
    subscribeToPostUpdates(); // enable realtime updates
    startSyncTimer();         // fallback polling
  }

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
      await prefs.setStringList(
        'saved_social_post_ids',
        savedSocialPostIds.toList(),
      );
      await prefs.setStringList('hidden_post_ids', hiddenPostIds.toList());

      final postsJson = jsonEncode(
        postsNotifier.value.map((p) => p.toJson()).toList(),
      );
      await prefs.setString('user_posts', postsJson);
    } catch (e) {
      debugPrint("Error saving to local: $e");
    }
  }

  Future<void> syncOnlinePosts() async {
    try {
      await syncLikes();
      final currentUser = UserStore.instance.currentUser;
      final currentUuid = Supabase.instance.client.auth.currentUser?.id;

      // Fetch posts:
      // - All public posts (saved_in_profile=false AND is_private=false)
      // - User's own posts (any visibility)
      // - Friends' private posts (is_private=true from people the current user follows)
      final List<dynamic> response;

      if (currentUser != null && currentUuid != null) {
        // Fetch the UUIDs of people this user follows
        final followsRes = await Supabase.instance.client
            .from('user_follows')
            .select('followed_id')
            .eq('follower_id', currentUuid);
        final followedUuids = (followsRes as List)
            .map((r) => r['followed_id'].toString())
            .toList();

        // Build an OR filter:
        // 1. Public posts (not private, not saved in profile)
        // 2. Own posts
        // 3. Private posts from followed users (friends)
        if (followedUuids.isEmpty) {
          response = await Supabase.instance.client
              .from('posts')
              .select()
              .or('saved_in_profile.eq.false,user_id.eq.${currentUser.userId}');
        } else {
          // Fetch public posts + own posts
          final publicAndOwnRes = await Supabase.instance.client
              .from('posts')
              .select()
              .or('saved_in_profile.eq.false,user_id.eq.${currentUser.userId}');

          // Merge (dedup by id) — is_private filtering handled client-side
          response = publicAndOwnRes;
        }
      } else {
        // Unauthenticated: fetch all non-profile-saved posts; filter client-side
        response = await Supabase.instance.client
            .from('posts')
            .select()
            .eq('saved_in_profile', false);
      }

      final List<UserPost> onlinePosts = [];
      for (var p in response) {
        try {
          onlinePosts.add(UserPost.fromJson(p as Map<String, dynamic>));
        } catch (e) {
          debugPrint("Error parsing online post: $e");
        }
      }

      // Fetch user's social stats: likes, saves, hidden
      if (currentUser != null) {
        final likesData = await Supabase.instance.client
            .from('post_likes')
            .select('post_id')
            .eq('user_id', currentUser.userId);
        likedPostIdsNotifier.value = (likesData as List).map((l) => l['post_id'] as String).toSet();

        final savesData = await Supabase.instance.client
            .from('post_saves')
            .select('post_id')
            .eq('user_id', currentUser.userId);
        savedSocialPostIdsNotifier.value = (savesData as List).map((s) => s['post_id'] as String).toSet();

        final hiddenData = await Supabase.instance.client
            .from('post_hidden')
            .select('post_id')
            .eq('user_id', currentUser.userId);
        hiddenPostIdsNotifier.value = (hiddenData as List).map((h) => h['post_id'] as String).toSet();
      }

      // Merge online with local private posts (if any aren't synced yet)
      final List<UserPost> currentPosts = List.from(postsNotifier.value);
      final Map<String, UserPost> mergedMap = {};

      for (var p in onlinePosts) {
        mergedMap[p.id] = p;
      }
      for (var p in currentPosts) {
        if (!mergedMap.containsKey(p.id)) {
          final isOwnPost = currentUser != null &&
              (p.username == currentUser.userId || p.username == currentUser.name);
          if (p.savedInProfile || _pendingUploadIds.contains(p.id) || isOwnPost) {
            mergedMap[p.id] = p;
          }
        }
      }

      final List<UserPost> finalPosts = mergedMap.values.toList();
      finalPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Update and save local state
      postsNotifier.value = finalPosts;
      await saveToLocal();
    } catch (e) {
      debugPrint("Error syncing online posts: $e");
    }
  }

  Future<String?> _uploadFile(String localPath, String folder, String filename) async {
    try {
      final file = File(localPath);
      if (!file.existsSync()) return null;

      final storagePath = '$folder/$filename';
      await Supabase.instance.client.storage
          .from('post-media')
          .upload(storagePath, file, fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('post-media')
          .getPublicUrl(storagePath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading file to storage: $e');
      return null;
    }
  }

  Future<void> uploadPostOnline(UserPost newPost) async {
    _pendingUploadIds.add(newPost.id);
    try {
      final currentUser = UserStore.instance.currentUser;
      
      // Upload media if present
      String? imageUrl = newPost.imageUrl;
      if (imageUrl == null && newPost.imagePath != null) {
        imageUrl = await _uploadFile(
          newPost.imagePath!,
          newPost.id,
          'image_${DateTime.now().millisecondsSinceEpoch}.png',
        );
      }

      String? videoUrl = newPost.videoUrl;
      if (videoUrl == null && newPost.videoPath != null) {
        videoUrl = await _uploadFile(
          newPost.videoPath!,
          newPost.id,
          'video_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
      }

      String? fileUrl = newPost.fileUrl;
      if (fileUrl == null && newPost.filePath != null) {
        final ext = newPost.type == 'document' ? 'pdf' : 'bin';
        fileUrl = await _uploadFile(
          newPost.filePath!,
          newPost.id,
          'file_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
      }

      List<String>? fileUrls = newPost.fileUrls;
      if (fileUrls == null && newPost.filePaths != null) {
        fileUrls = [];
        for (int i = 0; i < newPost.filePaths!.length; i++) {
          final ext = newPost.type == 'document' ? 'pdf' : 'bin';
          final url = await _uploadFile(
            newPost.filePaths![i],
            newPost.id,
            'file_${DateTime.now().millisecondsSinceEpoch}_$i.$ext',
          );
          if (url != null) fileUrls.add(url);
        }
      }

      // Upsert to Database
      final dbPost = {
        'id': newPost.id,
        'user_id': currentUser?.userId,
        'title': newPost.title,
        'body': newPost.body,
        'url': newPost.url,
        'type': newPost.type,
        'saved_in_profile': newPost.savedInProfile,
        'is_locked': newPost.isLocked,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'file_url': fileUrl,
        'file_urls': fileUrls,
        'contact_names': newPost.contactNames,
        'contact_phones': newPost.contactPhones,
        'duration': newPost.duration,
        'checklist_items': newPost.checklistItems,
        'checklist_states': newPost.checklistStates,
        'char_styles': newPost.charStyles?.map((s) => s.toJson()).toList(),
        'created_at': newPost.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('posts').upsert(dbPost);
      debugPrint("Post uploaded successfully to Supabase.");
      _pendingUploadIds.remove(newPost.id);
    } catch (e) {
      debugPrint("Error uploading post to Supabase: $e");
    }
  }

  /// Toggles the liked status of a post.
  void toggleLikedPost(String postId) async {
    final currentUser = UserStore.instance.currentUser;
    if (currentUser == null) return;

    final current = Set<String>.from(likedPostIds);
    bool isLiked = false;
    if (current.contains(postId)) {
      current.remove(postId);
      try {
        await Supabase.instance.client
            .from('post_likes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser.userId);
      } catch (e) {
        debugPrint('Error deleting like: $e');
      }
    } else {
      current.add(postId);
      isLiked = true;
      try {
        await Supabase.instance.client
            .from('post_likes')
            .insert({'post_id': postId, 'user_id': currentUser.userId});
      } catch (e) {
        debugPrint('Error inserting like: $e');
      }
    }
    likedPostIdsNotifier.value = current;
    saveToLocal();

    if (isLiked) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'liked',
        postTitle: details['title']!,
        author: details['author']!,
        postAuthorId: details['author']!,
        postId: postId,
      );
    }
  }

  /// Hides a post so it no longer appears in the feed.
  void hidePost(String postId) async {
    final currentUser = UserStore.instance.currentUser;
    if (currentUser == null) return;

    final current = Set<String>.from(hiddenPostIds);
    current.add(postId);
    hiddenPostIdsNotifier.value = current;
    saveToLocal();

    try {
      await Supabase.instance.client
          .from('post_hidden')
          .insert({'post_id': postId, 'user_id': currentUser.userId});
    } catch (e) {
      debugPrint('Error hiding post: $e');
    }
  }

  /// Unhides a previously hidden post.
  void unhidePost(String postId) async {
    final currentUser = UserStore.instance.currentUser;
    if (currentUser == null) return;

    final current = Set<String>.from(hiddenPostIds);
    current.remove(postId);
    hiddenPostIdsNotifier.value = current;
    saveToLocal();

    try {
      await Supabase.instance.client
          .from('post_hidden')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', currentUser.userId);
    } catch (e) {
      debugPrint('Error unhiding post: $e');
    }
  }

  /// Helper to get post details (title and author) for notifications.
  Map<String, String> getPostDetails(String postId) {
    for (final p in predefinedPosts) {
      if (p.id == postId) {
        return {
          'title': p.title ?? 'Untitled Post',
          'author': p.username ?? 'someone',
        };
      }
    }
    for (final p in posts) {
      if (p.id == postId) {
        return {'title': p.title, 'author': p.username ?? 'You'};
      }
    }
    return {'title': 'Untitled Post', 'author': 'someone'};
  }

  /// Adds a post and notifies all listeners.
  void addPost(UserPost post) async {
    postsNotifier.value = [post, ...postsNotifier.value];
    saveToLocal();

    // Async upload in the background
    uploadPostOnline(post);

    if (post.savedInProfile) {
      NotificationManager.instance.triggerVaultReminderNotification(post.title);
    } else {
      savedSocialPostIdsNotifier.value = {
        post.id,
        ...savedSocialPostIdsNotifier.value,
      };
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
    uploadPostOnline(updatedPost); // upload changes
  }

  /// Removes multiple posts by ID and notifies all listeners.
  void removeUserPosts(Set<String> postIds) async {
    postsNotifier.value = postsNotifier.value
        .where((post) => !postIds.contains(post.id))
        .toList();
    saveToLocal();

    try {
      await Supabase.instance.client
          .from('posts')
          .delete()
          .inFilter('id', postIds.toList());
    } catch (e) {
      debugPrint('Error deleting posts online: $e');
    }
  }

  /// Locks multiple posts by ID and notifies all listeners.
  void lockUserPosts(Set<String> postIds) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (postIds.contains(post.id)) {
        final updated = UserPost(
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
          imageUrl: post.imageUrl,
          videoUrl: post.videoUrl,
          fileUrl: post.fileUrl,
          fileUrls: post.fileUrls,
        );
        uploadPostOnline(updated);
        return updated;
      }
      return post;
    }).toList();
    saveToLocal();
  }

  /// Unlocks multiple posts by ID and notifies all listeners.
  void unlockUserPosts(Set<String> postIds) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (postIds.contains(post.id)) {
        final updated = UserPost(
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
          imageUrl: post.imageUrl,
          videoUrl: post.videoUrl,
          fileUrl: post.fileUrl,
          fileUrls: post.fileUrls,
        );
        uploadPostOnline(updated);
        return updated;
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
        final updated = UserPost(
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
          imageUrl: post.imageUrl,
          videoUrl: post.videoUrl,
          fileUrl: post.fileUrl,
          fileUrls: post.fileUrls,
        );
        uploadPostOnline(updated);
        return updated;
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
  void updatePostText(
    String postId,
    String newBody,
    List<RichStyle>? charStyles,
  ) {
    postsNotifier.value = postsNotifier.value.map((post) {
      if (post.id == postId) {
        final updated = UserPost(
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
          imageUrl: post.imageUrl,
          videoUrl: post.videoUrl,
          fileUrl: post.fileUrl,
          fileUrls: post.fileUrls,
        );
        uploadPostOnline(updated);
        return updated;
      }
      return post;
    }).toList();
    saveToLocal();
  }

  /// Toggles the saved status of a social post.
  void toggleSavedSocialPost(String postId) async {
    final currentUser = UserStore.instance.currentUser;
    if (currentUser == null) return;

    final current = Set<String>.from(savedSocialPostIds);
    bool isSaved = false;
    if (current.contains(postId)) {
      current.remove(postId);
      try {
        await Supabase.instance.client
            .from('post_saves')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', currentUser.userId);
      } catch (e) {
        debugPrint('Error deleting save: $e');
      }
    } else {
      current.add(postId);
      isSaved = true;
      try {
        await Supabase.instance.client
            .from('post_saves')
            .insert({'post_id': postId, 'user_id': currentUser.userId});
      } catch (e) {
        debugPrint('Error inserting save: $e');
      }
    }
    savedSocialPostIdsNotifier.value = current;
    saveToLocal();

    if (isSaved) {
      final details = getPostDetails(postId);
      NotificationManager.instance.triggerUserActionNotification(
        action: 'saved',
        postTitle: details['title']!,
        author: details['author']!,
        postAuthorId: details['author']!,
        postId: postId,
      );
    }
  }

  // ── Comments Section ──────────────────────────────────────────────────────

  Future<void> loadCommentsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('post_comments');
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        final Map<String, List<CommentModel>> loaded = {};
        bool wasPolluted = false;
        decoded.forEach((postId, list) {
          if (list is List) {
            final List<CommentModel> uniqueComments = [];
            final Set<String> seenIds = {};
            for (var item in list) {
              try {
                final comment = CommentModel.fromJson(Map<String, dynamic>.from(item as Map));
                if (!seenIds.contains(comment.id)) {
                  seenIds.add(comment.id);
                  uniqueComments.add(comment);
                } else {
                  wasPolluted = true;
                }
              } catch (e) {
                debugPrint("Error parsing comment: $e");
              }
            }
            loaded[postId] = uniqueComments;
          }
        });
        commentsNotifier.value = loaded;
        if (wasPolluted) {
          await saveCommentsToLocal();
        }
      }
    } catch (e) {
      debugPrint("Error loading comments from local: $e");
    }
  }

  Future<void> saveCommentsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> toSave = {};
      comments.forEach((postId, list) {
        toSave[postId] = list.map((c) => c.toJson()).toList();
      });
      await prefs.setString('post_comments', jsonEncode(toSave));
    } catch (e) {
      debugPrint("Error saving comments to local: $e");
    }
  }

  List<CommentModel> _getMockCommentsForPost(String postId) {
    return [
      CommentModel(
        id: '${postId}_c1',
        postId: postId,
        username: 'design_curator',
        avatarSeed: 'curator',
        text: 'The lighting in this shot is absolutely spectacular! ✨',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        likesCount: 14,
      ),
      CommentModel(
        id: '${postId}_c2',
        postId: postId,
        username: 'pixel_perfect',
        avatarSeed: 'pixel',
        text: 'Incredible composition. What lens did you use for this?',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        likesCount: 8,
      ),
      CommentModel(
        id: '${postId}_c3',
        postId: postId,
        username: 'nomad_adventurer',
        avatarSeed: 'nomad',
        text: 'This makes me want to pack my bags and travel immediately! 🌍',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        likesCount: 22,
      ),
      CommentModel(
        id: '${postId}_c4',
        postId: postId,
        username: 'aesthetic_vibes',
        avatarSeed: 'vibes',
        text: 'Such clean work, love the overall aesthetic here.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        likesCount: 5,
      ),
    ];
  }

  Future<void> fetchCommentsForPost(String postId) async {
    try {
      final response = await Supabase.instance.client
          .from('post_comments')
          .select()
          .eq('post_id', postId);
      
      final List<CommentModel> list = [];
      for (var item in response) {
        list.add(CommentModel.fromJson(Map<String, dynamic>.from(item as Map)));
      }
      
      final current = Map<String, List<CommentModel>>.from(comments);
      current[postId] = list;
      commentsNotifier.value = current;
    } catch (e) {
      debugPrint("Error fetching comments from Supabase (falling back to local): $e");
    }
  }

  List<CommentModel> getCommentsForPost(String postId) {
    final list = comments[postId];
    if (list != null) {
      return list;
    }
    // Async fetch in background from Supabase
    fetchCommentsForPost(postId);
    // Return empty list as temporary fallback/placeholder
    return [];
  }

  void addComment(String postId, String text) async {
    final current = Map<String, List<CommentModel>>.from(comments);
    final user = UserStore.instance.currentUser;
    final username = user?.name ?? user?.userId ?? 'Anonymous';
    final avatarSeed = DiceAvatar.seedNotifier.value;

    final newComment = CommentModel(
      id: '${postId}_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      username: username,
      avatarSeed: avatarSeed,
      text: text,
      createdAt: DateTime.now(),
    );

    if (current.containsKey(postId)) {
      current[postId] = [...current[postId]!, newComment];
    } else {
      current[postId] = [newComment];
    }
    commentsNotifier.value = current;

    // Trigger local notification to feel alive!
    final details = getPostDetails(postId);
    NotificationManager.instance.triggerUserActionNotification(
      action: 'commented: "$text"',
      postTitle: details['title']!,
      author: username,
      postAuthorId: details['author']!,
      postId: postId,
    );

    // Save locally as a backup
    saveCommentsToLocal();

    // Async upload to Supabase in the background
    try {
      await Supabase.instance.client.from('post_comments').insert({
        'id': newComment.id,
        'post_id': newComment.postId,
        'username': newComment.username,
        'avatar_seed': newComment.avatarSeed,
        'text': newComment.text,
        'created_at': newComment.createdAt.toIso8601String(),
        'likes_count': newComment.likesCount,
      });
      debugPrint("Comment synced to Supabase successfully.");
    } catch (e) {
      debugPrint("Error syncing comment to Supabase: $e");
    }
  }

  void toggleLikeComment(String postId, String commentId) async {
    final current = Map<String, List<CommentModel>>.from(comments);
    final List<CommentModel> list;
    if (current.containsKey(postId)) {
      list = current[postId]!;
    } else {
      list = _getMockCommentsForPost(postId);
    }

    int newLikes = 0;
    current[postId] = list.map((c) {
      if (c.id == commentId) {
        final isLiked = !c.isLikedByMe;
        newLikes = c.likesCount + (isLiked ? 1 : -1);
        return c.copyWith(
          likesCount: newLikes,
          isLikedByMe: isLiked,
        );
      }
      return c;
    }).toList();
    commentsNotifier.value = current;

    // Save locally as backup
    saveCommentsToLocal();

    // Async update in Supabase
    try {
      await Supabase.instance.client
          .from('post_comments')
          .update({'likes_count': newLikes})
          .eq('id', commentId);
      debugPrint("Comment likes updated in Supabase.");
    } catch (e) {
      debugPrint("Error updating comment likes in Supabase: $e");
    }
  }

  Future<void> syncLikes() async {
    try {
      final List<dynamic> allLikesRes = await Supabase.instance.client
          .from('post_likes')
          .select('post_id');
      final Map<String, int> likesMap = {};
      for (var item in allLikesRes) {
        final pId = item['post_id'] as String?;
        if (pId != null) {
          likesMap[pId] = (likesMap[pId] ?? 0) + 1;
        }
      }
      postLikesCountNotifier.value = likesMap;
      debugPrint('Likes counts synced successfully.');
    } catch (e) {
      debugPrint("Error syncing likes: $e");
    }
  }

  /// The predefined posts imported from the Figma mock designs.
  static final List<PostModel> predefinedPosts = [];
}
