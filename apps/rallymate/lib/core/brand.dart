/// User-facing product branding.
///
/// Technical identifiers (package name, deep-link scheme, Firebase, method
/// channels, env defines) stay on the historical `rallymate` namespace to avoid
/// breaking builds and store configurations.
library;

abstract final class AppBrand {
  static const name = 'Padelandia';
  static const nameUpper = 'PADELANDIA';
  static const tagline = 'Padel companion';

  /// Conversational AI coach mascot (chatbot / rules assistant).
  static const assistantName = 'Pallino';
  static const assistantFullName = 'Pallino Assistant';

  /// Optimized GLB mascots for **phone** UI only (see `assets/mesh-3d/`).
  /// Watch / Wear / Garmin / Fitbit companions stay 2D-text lightweight —
  /// no model_viewer WebView on those surfaces.
  /// - [assistantGlb]: chat / FAB avatar (tennis-ball mascot)
  /// - [tipGlb]: coach tip / lavagna (tip mascot variant)
  static const assistantGlb = 'assets/mesh-3d/pallino.glb';
  static const tipGlb = 'assets/mesh-3d/pallino_tip.glb';
}
