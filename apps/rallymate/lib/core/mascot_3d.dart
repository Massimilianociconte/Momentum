import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'brand.dart';

/// Which optimized GLB mascot to render.
enum Mascot3dKind {
  /// Chat / assistant avatar ("Pallino").
  assistant,

  /// Coach tip / lavagna / home footer tip mascot.
  tip,
}

/// Compact 3D mascot for chat, FAB, training and home.
///
/// Uses [model_viewer_plus] (local HttpServer + WebView). Gestures are ignored
/// so parent buttons/cards keep receiving taps.
///
/// Reliability notes (Android):
/// - GLB must not require meshopt/webp as required extensions
/// - cleartext to 127.0.0.1 must be allowed (network security config)
/// - prefer an opaque WebView background (transparent often blanks hybrid views)
class Mascot3d extends StatelessWidget {
  const Mascot3d({
    super.key,
    this.kind = Mascot3dKind.assistant,
    this.size = 64,
    this.autoRotate = true,
    this.borderRadius,
    this.backgroundColor,
  });

  final Mascot3dKind kind;
  final double size;
  final bool autoRotate;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  String get _src => switch (kind) {
    Mascot3dKind.assistant => AppBrand.assistantGlb,
    Mascot3dKind.tip => AppBrand.tipGlb,
  };

  String get _alt => switch (kind) {
    Mascot3dKind.assistant => AppBrand.assistantName,
    Mascot3dKind.tip => '${AppBrand.assistantName} tip',
  };

  static String _cssHex(Color color) {
    final argb = color.toARGB32();
    return (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  }

  @override
  Widget build(BuildContext context) {
    final radius =
        borderRadius ?? BorderRadius.circular((size * 0.22).clamp(8, 22));
    // Opaque bg: transparent WebGL surfaces often fail to composite on Android.
    final bg = backgroundColor ?? const Color(0xFF0B1524);
    final bgHex = _cssHex(bg);

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: ColoredBox(
            color: bg,
            child: IgnorePointer(
              child: ModelViewer(
                key: ValueKey('mascot3d-${kind.name}-$size-v3'),
                src: _src,
                alt: _alt,
                backgroundColor: bg,
                autoRotate: autoRotate,
                autoRotateDelay: 0,
                rotationPerSecond: '30deg',
                cameraControls: false,
                disableZoom: true,
                disablePan: true,
                disableTap: true,
                interactionPrompt: InteractionPrompt.none,
                loading: Loading.eager,
                debugLogging: kDebugMode,
                shadowIntensity: 0.3,
                shadowSoftness: 1,
                exposure: 1.2,
                cameraOrbit: '0deg 75deg 2.2m',
                fieldOfView: '32deg',
                environmentImage: 'neutral',
                relatedCss:
                    '''
body { background-color: #$bgHex; overflow: hidden; }
model-viewer {
  width: 100%;
  height: 100%;
  background-color: #$bgHex;
  --poster-color: transparent;
}
''',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
