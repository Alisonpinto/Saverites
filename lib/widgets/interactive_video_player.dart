import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'shimmer_container.dart';

class InteractiveVideoPlayer extends StatefulWidget {
  final File? file;
  final String? assetPath;
  final double? height;

  const InteractiveVideoPlayer({
    super.key,
    this.file,
    this.assetPath,
    this.height,
  });

  @override
  State<InteractiveVideoPlayer> createState() => _InteractiveVideoPlayerState();
}

class _InteractiveVideoPlayerState extends State<InteractiveVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initialize() {
    if (widget.file != null) {
      _controller = VideoPlayerController.file(widget.file!);
    } else if (widget.assetPath != null && widget.assetPath!.isNotEmpty) {
      _controller = VideoPlayerController.asset(widget.assetPath!);
    }

    if (_controller == null) return;

    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = _controller!.value.isPlaying;
        });
        _controller!.setLooping(true);
        // Do NOT play automatically as requested
        // Let audio be on by default unless muted
        _controller!.setVolume(_isMuted ? 0.0 : 1.0);
        
        _controller!.addListener(_videoListener);
      }
    }).catchError((error) {
      debugPrint('Video player initialization failed: $error');
    });
  }
  
  void _videoListener() {
    if (mounted && _controller != null) {
      if (_isPlaying != _controller!.value.isPlaying) {
        setState(() {
          _isPlaying = _controller!.value.isPlaying;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file?.path != oldWidget.file?.path || widget.assetPath != oldWidget.assetPath) {
      _controller?.removeListener(_videoListener);
      _controller?.dispose();
      _isInitialized = false;
      _initialize();
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_isInitialized) {
      return ShimmerContainer(
        height: widget.height ?? 200,
        baseColor: const Color(0xFF2A2A2E),
        borderRadius: 0,
      );
    }

    Widget player = AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );

    if (widget.height != null) {
      player = SizedBox(
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

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        alignment: Alignment.center,
        children: [
          player,
          if (!_isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
