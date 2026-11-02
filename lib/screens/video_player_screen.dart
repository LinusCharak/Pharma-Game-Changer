import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models/demo_video.dart';
import '../theme/app_theme.dart';

/// Plays a single DemoVideo, with a tap-to-reveal control overlay and a
/// real fullscreen mode (forces landscape + hides system UI, reusing the
/// same controller so playback position is preserved).
class VideoPlayerScreen extends StatefulWidget {
  final DemoVideo video;
  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      _controller.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _error = "Couldn't load this video. Check your connection and try again.");
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Always leave the device back in normal portrait / system-UI state,
    // even if the user backed out of this screen while in fullscreen.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPage(controller: _controller, title: widget.video.title),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.video.title)),
      backgroundColor: Colors.black,
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
              )
            : !_initialized
                ? const CircularProgressIndicator(color: AppColors.gold)
                : _VideoControls(controller: _controller, onFullscreen: _openFullscreen),
      ),
    );
  }
}

/// Shared control overlay: tap to show/hide, play/pause, seek bar,
/// fullscreen toggle. Used both inline and in the fullscreen page below.
class _VideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback? onFullscreen;
  final bool isFullscreen;
  const _VideoControls({required this.controller, this.onFullscreen, this.isFullscreen = false});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerTick);
    _scheduleHide();
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _togglePlayback() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _scheduleHide();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    _hideTimer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final value = c.value;
    final durationMs = value.duration.inMilliseconds;

    return GestureDetector(
      onTap: _toggleControls,
      child: AspectRatio(
        aspectRatio: value.isInitialized && value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            VideoPlayer(c),
            if (_showControls) ...[
              Container(color: Colors.black26),
              IconButton(
                iconSize: 56,
                color: Colors.white,
                icon: Icon(value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                onPressed: _togglePlayback,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_format(value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: durationMs == 0
                                ? 0
                                : value.position.inMilliseconds.clamp(0, durationMs).toDouble(),
                            max: durationMs == 0 ? 1 : durationMs.toDouble(),
                            activeColor: AppColors.gold,
                            inactiveColor: Colors.white30,
                            onChanged: (v) => c.seekTo(Duration(milliseconds: v.round())),
                          ),
                        ),
                      ),
                      Text(_format(value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      if (widget.onFullscreen != null)
                        IconButton(
                          icon: const Icon(Icons.fullscreen, color: Colors.white),
                          tooltip: 'Fullscreen',
                          onPressed: widget.onFullscreen,
                        ),
                      if (widget.isFullscreen)
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                          tooltip: 'Exit fullscreen',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Landscape, immersive (system bars hidden) fullscreen playback. Reuses
/// the same VideoPlayerController the inline player was using, so exiting
/// fullscreen resumes exactly where it left off with no reload/flicker.
class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  const _FullscreenVideoPage({required this.controller, required this.title});

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _VideoControls(controller: widget.controller, isFullscreen: true),
        ),
      ),
    );
  }
}
