import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'notification_manager.dart';

class ShareHelper {
  /// Shares a post natively.
  ///
  /// Concurrently supports:
  /// - [localImagePath]: Absolute path to a local image on disk.
  /// - [localVideoPath]: Absolute path to a local video on disk.
  /// - [assetPath]: Asset location (e.g., 'assets/images/outfit.png') that will be cached temporarily.
  /// - [title], [description], and [url] text metadata.
  static Future<void> sharePost({
    required String title,
    String? description,
    String? url,
    String? localImagePath,
    String? localVideoPath,
    String? assetPath,
    String? author,
    String? postId,
  }) async {
    final bool hasUrl = url != null && url.trim().isNotEmpty;

    // Build the share text structure
    final List<String> textParts = [];
    if (title.isNotEmpty) {
      textParts.add(title); // Keep original casing instead of toUpperCase
    }
    if (description != null && description.trim().isNotEmpty) {
      textParts.add(description.trim());
    }
    if (hasUrl) {
      textParts.add(url.trim());
    }
    
    textParts.add('—\nShared via Memoria');
    
    final String shareText = textParts.join('\n\n');

    try {
      String? filePathToShare;

      // 1. Check local video path
      if (localVideoPath != null && localVideoPath.isNotEmpty) {
        final file = File(localVideoPath);
        if (await file.exists()) {
          try {
            final tempDir = await getTemporaryDirectory();
            final thumbPath = await VideoThumbnail.thumbnailFile(
              video: localVideoPath,
              thumbnailPath: tempDir.path,
              imageFormat: ImageFormat.JPEG,
              maxHeight: 1024,
              quality: 75,
            );
            if (thumbPath != null) {
              filePathToShare = thumbPath;
            } else {
              filePathToShare = localVideoPath;
            }
          } catch (e) {
            debugPrint('Failed to generate video thumbnail: $e');
            filePathToShare = localVideoPath;
          }
        }
      }
      // 2. Check local image path (if no video was resolved)
      if (filePathToShare == null && localImagePath != null && localImagePath.isNotEmpty) {
        final file = File(localImagePath);
        if (await file.exists()) {
          filePathToShare = localImagePath;
        }
      }
      // 3. Check asset path (predefined media assets)
      if (filePathToShare == null && assetPath != null && assetPath.isNotEmpty) {
        try {
          final ByteData byteData = await rootBundle.load(assetPath);
          final Directory tempDir = Directory.systemTemp;
          final String fileName = assetPath.split('/').last;
          final File file = File('${tempDir.path}/shared_post_asset_$fileName');
          
          await file.writeAsBytes(byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ));
          filePathToShare = file.path;
        } catch (assetError) {
          debugPrint('Error loading asset for sharing ($assetPath): $assetError');
        }
      }

      // Perform the share action using the standard Share API
      if (filePathToShare != null) {
        await Share.shareXFiles(
          [XFile(filePathToShare)],
          text: shareText,
        );
      } else {
        await Share.share(shareText);
      }

      // Trigger user action notification
      NotificationManager.instance.triggerUserActionNotification(
        action: 'shared',
        postTitle: title,
        author: author,
      );
    } catch (e) {
      debugPrint('Error sharing post natively: $e');
      // Graceful fallback to text-only share
      try {
        await Share.share(shareText);
      } catch (fallbackError) {
        debugPrint('Fallback sharing also failed: $fallbackError');
      }
    }
  }
}
