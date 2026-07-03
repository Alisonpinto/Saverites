import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'shimmer_container.dart';

class InteractiveVideoPlayer extends StatefulWidget {
  final File? file;
  final String? assetPath;
  final String? videoUrl;
  final double? height;
  final bool autoPlay;

  const InteractiveVideoPlayer({
    super.key,
    this.file,
    this.assetPath,
    this.videoUrl,
    this.height,
    this.autoPlay = true,
  });

  @override
  State<InteractiveVideoPlayer> createState() => _InteractiveVideoPlayerState();
}

class _InteractiveVideoPlayerState extends State<InteractiveVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_isInitialized) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller!.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_isPlaying) _controller!.play();
    }
  }

  void _initialize() {
    VideoPlayerController? ctrl;
    if (widget.file != null) {
      ctrl = VideoPlayerController.file(widget.file!);
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
    } else if (widget.assetPath != null && widget.assetPath!.isNotEmpty) {
      ctrl = VideoPlayerController.asset(widget.assetPath!);
    }

    if (ctrl == null) return;
    _controller = ctrl;

    _controller!.initialize().then((_) {
      if (_disposed || !mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
      _controller!.addListener(_videoListener);

      if (!_disposed && mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = widget.autoPlay;
        });

        if (widget.autoPlay) {
          _controller!.play();
        }
      }
    }).catchError((err) {
      debugPrint('[InteractiveVideoPlayer] init error: $err');
    });
  }

  void _videoListener() {
    if (_disposed || !mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (_isPlaying != playing) {
      setState(() {
        _isPlaying = playing;
      });
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final fileChanged = widget.file?.path != oldWidget.file?.path;
    final assetChanged = widget.assetPath != oldWidget.assetPath;
    final urlChanged = widget.videoUrl != oldWidget.videoUrl;
    if (fileChanged || assetChanged || urlChanged) {
      _controller?.removeListener(_videoListener);
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _isPlaying = false;
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
        height: widget.height ?? 260,
        baseColor: const Color(0xFF1A1A1A),
        borderRadius: 0,
      );
    }

    final aspectRatio = _controller!.value.aspectRatio;

    Widget videoWidget = AspectRatio(
      aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
      child: VideoPlayer(_controller!),
    );

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Video ──────────────────────────────────────────────────────────
          videoWidget,

          // ── Centre play/pause overlay ──────────────────────────────────────
          AnimatedOpacity(
            opacity: !_isPlaying ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),

          // ── Bottom controls bar ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Play/pause mini button
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Seek bar
                  Expanded(
                    child: VideoProgressIndicator(
                      _controller!,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white12,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Mute button
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
