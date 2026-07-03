import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'shimmer_container.dart';

/// A silent, auto-looping video player used in the feed/profile grid cards.
///
/// Automatically pauses when another route is pushed on top (e.g. detail screen)
/// and resumes when popped back.
class RunningVideoPlayer extends StatefulWidget {
  final File? file;
  final String? assetPath;
  final String? videoUrl;
  final double? height;

  /// Global route observer — must be registered in [MaterialApp.navigatorObservers].
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

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

class _RunningVideoPlayerState extends State<RunningVideoPlayer>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      RunningVideoPlayer.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    RunningVideoPlayer.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  // ── RouteAware callbacks ─────────────────────────────────────────────────

  /// Called when this route becomes the top-most route (e.g. detail screen popped).
  @override
  void didPopNext() {
    _resumeIfReady();
  }

  /// Called when a new route is pushed on top of this one.
  @override
  void didPushNext() {
    _pauseIfPlaying();
  }

  // ── AppLifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pauseIfPlaying();
    } else if (state == AppLifecycleState.resumed) {
      _resumeIfReady();
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _pauseIfPlaying() {
    if (_isInitialized && _controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
    }
  }

  void _resumeIfReady() {
    if (!_disposed && mounted && _isInitialized && _controller != null) {
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrentRoute && !_controller!.value.isPlaying) {
        _controller!.play();
      }
    }
  }

  void _initialize() {
    if (widget.file != null) {
      _controller = VideoPlayerController.file(widget.file!);
    } else if (widget.assetPath != null && widget.assetPath!.isNotEmpty) {
      _controller = VideoPlayerController.asset(widget.assetPath!);
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl!));
    }

    if (_controller == null) return;

    _controller!.initialize().then((_) {
      if (_disposed || !mounted) return;
      _controller!.setLooping(true);
      _controller!.setVolume(0.0); // silent in feed

      setState(() {
        _isInitialized = true;
      });

      // Only play if this is still the top-most route.
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      if (isCurrentRoute) {
        _controller!.play();
      }
    }).catchError((error) {
      debugPrint('[RunningVideoPlayer] init error: $error');
    });
  }

  @override
  void didUpdateWidget(covariant RunningVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file?.path != oldWidget.file?.path ||
        widget.assetPath != oldWidget.assetPath ||
        widget.videoUrl != oldWidget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _initialize();
    }
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
