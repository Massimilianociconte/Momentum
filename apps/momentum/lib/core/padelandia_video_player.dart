/// Compact vertical demo video player for training drills / onboarding.
library;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'theme.dart';

class PadelandiaVideoPlayer extends StatefulWidget {
  const PadelandiaVideoPlayer({
    super.key,
    required this.assetPath,
    this.aspectRatio = 9 / 16,
    this.autoPlay = true,
    this.loop = true,
    this.borderRadius = 16,
    this.maxHeight = 280,
  });

  final String assetPath;
  final double aspectRatio;
  final bool autoPlay;
  final bool loop;
  final double borderRadius;
  final double maxHeight;

  @override
  State<PadelandiaVideoPlayer> createState() => _PadelandiaVideoPlayerState();
}

class _PadelandiaVideoPlayerState extends State<PadelandiaVideoPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant PadelandiaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _controller?.dispose();
      _controller = null;
      _error = null;
      _init();
    }
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.asset(widget.assetPath);
      await c.initialize();
      await c.setLooping(widget.loop);
      if (widget.autoPlay) await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _controller = c);
    } catch (e) {
      if (mounted) setState(() => _error = 'Video non disponibile');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error != null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: Text(_error!, style: const TextStyle(color: Colors.white54)),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return SizedBox(
        height: 160,
        child: Center(
          child: CircularProgressIndicator(
            color: RallyColors.lime.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.maxHeight),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (c.value.isPlaying) {
                          c.pause();
                        } else {
                          c.play();
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        c.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: RallyColors.lime,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'DEMO TECNICA',
                    style: TextStyle(
                      color: RallyColors.lime,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
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
