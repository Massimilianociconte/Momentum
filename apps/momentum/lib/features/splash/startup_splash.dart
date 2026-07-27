import 'dart:async';

import 'package:flutter/material.dart';

class StartupSplashGate extends StatefulWidget {
  const StartupSplashGate({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplashGate> createState() => _StartupSplashGateState();
}

class _StartupSplashGateState extends State<StartupSplashGate> {
  /// Brand beat without blocking first useful frame too long.
  static const _minimumDuration = Duration(milliseconds: 650);
  /// Hard cap so a slow first frame never traps the user on splash.
  static const _maximumDuration = Duration(milliseconds: 1600);
  var _visible = true;
  var _mountedOverlay = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Fade as soon as the first frame of the real tree is painted, but keep a
    // short brand beat and never exceed the max cap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timer?.cancel();
      _timer = Timer(_minimumDuration, () {
        if (mounted) setState(() => _visible = false);
      });
    });
    _timer = Timer(_maximumDuration, () {
      if (mounted && _visible) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_mountedOverlay)
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              onEnd: () {
                if (mounted && !_visible) {
                  setState(() => _mountedOverlay = false);
                }
              },
              child: const _StartupSplash(),
            ),
          ),
      ],
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final cacheWidth =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(720, 1440)
            .toInt();

    // Full-bleed original splash art is the hero — keep overlays light so the
    // neon racket composition stays visible (no large clashing app-icon plate).
    return ColoredBox(
      color: const Color(0xFF051120),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/brand/rallymate_loading_splash.jpg',
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            filterQuality: FilterQuality.medium,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66051120),
                  Color(0x14051120),
                  Color(0xB3051120),
                ],
                stops: [0, 0.42, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(flex: 7),
                  const Text(
                    'Momentum',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 38,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 18,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Segna. Analizza. Migliora.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xE6DDE7F2),
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: Color(0x88000000),
                          blurRadius: 12,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 1),
                  const _PulseLoader(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseLoader extends StatefulWidget {
  const _PulseLoader();

  @override
  State<_PulseLoader> createState() => _PulseLoaderState();
}

class _PulseLoaderState extends State<_PulseLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 118,
        height: 5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFFB9FF18), Color(0xFF42D9FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66B9FF18),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
