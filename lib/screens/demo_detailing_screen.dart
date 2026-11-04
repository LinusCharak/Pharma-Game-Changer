import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/demo_video.dart';
import '../services/demo_video_service.dart';

class DemoDetailingScreen extends StatefulWidget {
  const DemoDetailingScreen({super.key});

  @override
  State<DemoDetailingScreen> createState() =>
      _DemoDetailingScreenState();
}

class _DemoDetailingScreenState extends State<DemoDetailingScreen> {
  final DemoVideoService _service = DemoVideoService();

  late Future<List<DemoVideo>> _future;

  VideoPlayerController? _controller;
  DemoVideo? _selectedVideo;

  bool _videoInitialized = false;
  bool _showControls = true;
  String? _videoError;

  Timer? _hideControlsTimer;

  // Prevents an older video request from updating the screen
  // after another video has already been selected.
  int _videoRequestId = 0;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchVideos();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    super.dispose();
  }

  // ================================================================
  // REFRESH
  // ================================================================

  Future<void> _retry() async {
    final future = _service.fetchVideos();

    setState(() {
      _future = future;
    });

    await future;
  }

  // ================================================================
  // SELECT VIDEO
  // ================================================================

  Future<void> _selectVideo(DemoVideo video) async {
    final requestId = ++_videoRequestId;

    _hideControlsTimer?.cancel();

    final oldController = _controller;

    setState(() {
      _selectedVideo = video;
      _controller = null;
      _videoInitialized = false;
      _videoError = null;
      _showControls = true;
    });

    await oldController?.dispose();

    if (!mounted || requestId != _videoRequestId) {
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(video.videoUrl),
      );

      _controller = controller;

      await controller.initialize();

      if (!mounted || requestId != _videoRequestId) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoInitialized = true;
      });

      await controller.play();

      if (!mounted || requestId != _videoRequestId) {
        return;
      }

      _startControlsTimer();
    } catch (e) {
      if (!mounted || requestId != _videoRequestId) {
        return;
      }

      setState(() {
        _videoError = 'Unable to play this video.';
        _videoInitialized = false;
      });
    }
  }

  // ================================================================
  // CONTROLS VISIBILITY
  // ================================================================

  void _startControlsTimer() {
    _hideControlsTimer?.cancel();

    _hideControlsTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          _showControls = false;
        });
      },
    );
  }

  void _toggleControls() {
    if (!_videoInitialized) return;

    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startControlsTimer();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  // ================================================================
  // PLAY / PAUSE
  // ================================================================

  Future<void> _togglePlayPause() async {
    final controller = _controller;

    if (controller == null || !_videoInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      _hideControlsTimer?.cancel();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() {
          _showControls = true;
        });

        _startControlsTimer();
      }
    }
  }

  // ================================================================
  // FULLSCREEN
  // ================================================================

  Future<void> _openFullscreen() async {
    final controller = _controller;

    if (controller == null || !_videoInitialized) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(
          controller: controller,
          title: _selectedVideo?.title ?? 'Demo Detailing',
        ),
      ),
    );

    if (!mounted) return;

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    setState(() {
      _showControls = true;
    });

    _startControlsTimer();
  }

  // ================================================================
  // MAIN BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo Detailing'),
      ),
      body: FutureBuilder<List<DemoVideo>>(
        future: _future,
        builder: (context, snapshot) {
          // ----------------------------------------------------------
          // LOADING
          // ----------------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ----------------------------------------------------------
          // ERROR
          // ----------------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load Demo Detailing videos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final videos = snapshot.data ?? [];

          // ----------------------------------------------------------
          // EMPTY
          // ----------------------------------------------------------

          if (videos.isEmpty) {
            return const Center(
              child: Text(
                'No demo videos available.',
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            );
          }

          // ----------------------------------------------------------
          // PLAYER + SCROLLABLE LIST
          // ----------------------------------------------------------

          return Column(
            children: [
              _buildTopVideoArea(),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _retry,
                  child: ListView.builder(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    itemCount: videos.length,
                    itemBuilder: (context, index) {
                      final video = videos[index];

                      return _DemoVideoListItem(
                        video: video,
                        selected:
                            _selectedVideo?.id == video.id,
                        onTap: () {
                          _selectVideo(video);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================================================================
  // TOP VIDEO AREA
  // ================================================================

  Widget _buildTopVideoArea() {
    // The header / player is sized from the screen WIDTH. On a wide window
    // (Chrome) that makes it taller than the window and pushes the video
    // list out of view ("BOTTOM OVERFLOWED"). Limit its width so it never
    // takes more than about half of the height. On a phone in portrait the
    // limit is larger than the screen width, so nothing changes there.
    final size = MediaQuery.of(context).size;
    final maxWidth = math.min(
      size.width,
      math.max(320.0, size.height * 0.5 * (16 / 9)),
    );

    final Widget top;

    if (_selectedVideo == null) {
      top = const _DemoDetailingHeader();
    } else {
      top = _EmbeddedVideoPlayer(
        controller: _controller,
        initialized: _videoInitialized,
        error: _videoError,
        showControls: _showControls,
        title: _selectedVideo!.title,
        onTap: _toggleControls,
        onPlayPause: _togglePlayPause,
        onFullscreen: _openFullscreen,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: top,
      ),
    );
  }
}

// ====================================================================
// WELCOME HEADER
// ====================================================================

class _DemoDetailingHeader extends StatelessWidget {
  const _DemoDetailingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: AspectRatio(
        aspectRatio: 1.55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Blue play icon
            Container(
              width: 65,
              height: 65,
              decoration: const BoxDecoration(
                color: Color(0xFF2993CC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'Welcome to Demo Detailing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Please click product below',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const Text(
              'to start detailing',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// EMBEDDED VIDEO PLAYER
// ====================================================================

class _EmbeddedVideoPlayer extends StatelessWidget {
  final VideoPlayerController? controller;
  final bool initialized;
  final String? error;
  final bool showControls;
  final String title;

  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;

  const _EmbeddedVideoPlayer({
    required this.controller,
    required this.initialized,
    required this.error,
    required this.showControls,
    required this.title,
    required this.onTap,
    required this.onPlayPause,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final videoController = controller;

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio:
                initialized &&
                        videoController != null &&
                        videoController.value.aspectRatio > 0
                    ? videoController.value.aspectRatio
                    : 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ----------------------------------------------------
                // VIDEO
                // ----------------------------------------------------

                if (initialized && videoController != null)
                  VideoPlayer(videoController)
                else if (error == null)
                  const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),

                // ----------------------------------------------------
                // ERROR
                // ----------------------------------------------------

                if (error != null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ----------------------------------------------------
                // TAP AREA WHEN CONTROLS ARE HIDDEN
                // ----------------------------------------------------

                if (initialized && !showControls)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: const SizedBox.expand(),
                    ),
                  ),

                // ----------------------------------------------------
                // CONTROLS
                // ----------------------------------------------------

                if (initialized && showControls)
                  Positioned.fill(
                    child: _VideoControlsOverlay(
                      controller: videoController!,
                      onTap: onTap,
                      onPlayPause: onPlayPause,
                      onFullscreen: onFullscreen,
                    ),
                  ),
              ],
            ),
          ),

          // ----------------------------------------------------------
          // VIDEO TITLE
          // ----------------------------------------------------------

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            color: Colors.white,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// VIDEO CONTROLS
// ====================================================================

class _VideoControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;

  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;

  const _VideoControlsOverlay({
    required this.controller,
    required this.onTap,
    required this.onPlayPause,
    required this.onFullscreen,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final duration = value.duration;
        final position = value.position;

        final maxMilliseconds =
            duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1.0;

        final currentMilliseconds = position.inMilliseconds
            .clamp(0, duration.inMilliseconds)
            .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onTap,
          child: Stack(
            children: [
              // ------------------------------------------------------
              // BOTTOM GRADIENT
              // ------------------------------------------------------

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    height: 90,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ------------------------------------------------------
              // PLAY / PAUSE BUTTON
              // ------------------------------------------------------

              Center(
                child: GestureDetector(
                  onTap: onPlayPause,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: 0.55,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
              ),

              // ------------------------------------------------------
              // BOTTOM CONTROLS
              // ------------------------------------------------------

              Positioned(
                left: 8,
                right: 8,
                bottom: 4,
                child: Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),

                    Expanded(
                      child: Slider(
                        value: currentMilliseconds,
                        min: 0,
                        max: maxMilliseconds,
                        onChanged: (newValue) {
                          controller.seekTo(
                            Duration(
                              milliseconds: newValue.round(),
                            ),
                          );
                        },
                      ),
                    ),

                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),

                    IconButton(
                      onPressed: onFullscreen,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====================================================================
// VIDEO LIST ITEM
// ====================================================================

class _DemoVideoListItem extends StatelessWidget {
  final DemoVideo video;
  final bool selected;
  final VoidCallback onTap;

  const _DemoVideoListItem({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFE8EAF6)
          : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // Compact YouTube-style row.
          height: 100,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0xFFBDBDBD),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),

              // ------------------------------------------------------
              // THUMBNAIL WITH SHADOW
              // ------------------------------------------------------

              Container(
                width: 150,
                height: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 5,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    // Web only: load through a normal <img> tag so the
                    // picture shows even if its website sends no CORS
                    // headers. Ignored on Android.
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    loadingBuilder: (
                      context,
                      child,
                      loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: Colors.grey,
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // ------------------------------------------------------
              // VIDEO TITLE
              // ------------------------------------------------------

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 12,
                  ),
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// FULLSCREEN VIDEO PAGE
// ====================================================================

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;

  const _FullscreenVideoPage({
    required this.controller,
    required this.title,
  });

  @override
  State<_FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState
    extends State<_FullscreenVideoPage> {
  bool _showControls = true;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _startTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  void _startTimer() {
    _hideTimer?.cancel();

    _hideTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          _showControls = false;
        });
      },
    );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _startTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child: AspectRatio(
            aspectRatio:
                widget.controller.value.aspectRatio > 0
                    ? widget.controller.value.aspectRatio
                    : 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ----------------------------------------------------
                // VIDEO
                // ----------------------------------------------------

                VideoPlayer(widget.controller),

                // ----------------------------------------------------
                // CONTROLS
                // ----------------------------------------------------

                if (_showControls)
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, child) {
                      final duration = value.duration;
                      final position = value.position;

                      final maxMilliseconds =
                          duration.inMilliseconds > 0
                              ? duration.inMilliseconds
                                  .toDouble()
                              : 1.0;

                      final currentMilliseconds =
                          position.inMilliseconds
                              .clamp(
                                0,
                                duration.inMilliseconds,
                              )
                              .toDouble();

                      return Stack(
                        children: [
                          // BOTTOM GRADIENT
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              height: 90,
                              decoration:
                                  const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black87,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // PLAY / PAUSE
                          Center(
                            child: GestureDetector(
                              onTap: () async {
                                if (value.isPlaying) {
                                  await widget.controller
                                      .pause();
                                } else {
                                  await widget.controller
                                      .play();
                                }

                                if (mounted) {
                                  setState(() {});
                                  _startTimer();
                                }
                              },
                              child: Icon(
                                value.isPlaying
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.white,
                                size: 64,
                              ),
                            ),
                          ),

                          // BOTTOM CONTROLS
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: Row(
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),

                                Expanded(
                                  child: Slider(
                                    value:
                                        currentMilliseconds,
                                    min: 0,
                                    max:
                                        maxMilliseconds,
                                    onChanged: (newValue) {
                                      widget.controller
                                          .seekTo(
                                        Duration(
                                          milliseconds:
                                              newValue.round(),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                Text(
                                  _formatDuration(duration),
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),

                                IconButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pop();
                                  },
                                  icon: const Icon(
                                    Icons.fullscreen_exit,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}