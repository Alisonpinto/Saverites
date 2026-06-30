import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'shimmer_container.dart';

/// A premium, silent, looping video player that scales to cover its bounds.
///
/// Supports loading video from a local file path (for user posts) or
/// an asset path (for predefined posts).
class RunningVideoPlayer extends StatefulWidget {
  final File? file;
  final String? assetPath;
  final String? videoUrl;
  final double? height;

  const RunningVideoPlayer({
    super.key,
    this.file,
    this.assetPath,
    this.videoUrl,
    this.height,
  });

  @override
  State<RunningVideoPlayer> createState() => _RunningVideoPlayerState();
}

class _RunningVideoPlayerState extends State<RunningVideoPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrentRoute && _isInitialized && _controller != null && !_controller!.value.isPlaying) {
        _controller!.play();
      }
    } else if (state == AppLifecycleState.paused) {
      if (_isInitialized && _controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleRouteVisibility();
  }

  void _handleRouteVisibility() {
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
    if (_controller != null && _isInitialized) {
      if (isCurrentRoute) {
        if (!_controller!.value.isPlaying) {
          _controller!.play();
        }
      } else {
        if (_controller!.value.isPlaying) {
          _controller!.pause();
        }
      }
    }
  }

  void _initialize() {
    if (widget.file != null) {
      _controller = VideoPlayerController.file(widget.file!);
    } else if (widget.assetPath != null && widget.assetPath!.isNotEmpty) {
      _controller = VideoPlayerController.asset(widget.assetPath!);
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
    }

    if (_controller == null) return;

    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.setLooping(true);
        _controller!.setVolume(0.0);
        
        final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
        if (isCurrentRoute) {
          _controller!.play();
        }
      }
    }).catchError((error) {
      debugPrint('Video player initialization failed: $error');
    });
  }

  @override
  void didUpdateWidget(covariant RunningVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file?.path != oldWidget.file?.path || 
        widget.assetPath != oldWidget.assetPath || 
        widget.videoUrl != oldWidget.videoUrl) {
      _controller?.dispose();
      _isInitialized = false;
      _initialize();
    } else {
      _handleRouteVisibility();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isInitialized) {
      return ShimmerContainer(
        height: widget.height ?? 200,
        baseColor: const Color(0xFF2A2A2E),
        borderRadius: 0, // Let ClipRRect handle rounding
      );
    }

    if (widget.height == null) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
