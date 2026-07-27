/// User-facing product branding.
///
/// Technical identifiers (package name, deep-link scheme, Firebase, method
/// channels, env defines) stay on the historical `rallymate` namespace to avoid
/// breaking builds and store configurations.
library;

abstract final class AppBrand {
  static const name = 'Momentum';
  static const nameUpper = 'MOMENTUM';
  static const tagline = 'Padel companion';

  /// Conversational AI coach mascot (chatbot / rules assistant).
  static const assistantName = 'Pallino';
  static const assistantFullName = 'Pallino Assistant';

  /// Disclosure obbligatoria: l'utente deve sapere che sta interagendo con un
  /// sistema di IA (Reg. UE 2024/1689 art. 50 §1, applicabile dal 2 agosto
  /// 2026). Il nome della mascotte NON basta: non è "ovvio" ai sensi della
  /// norma. Va mostrata su ogni superficie conversazionale — telefono, Wear OS
  /// e watchOS — con lo stesso significato.
  static const assistantAiDisclosure =
      'Risposte generate da intelligenza artificiale: possono contenere '
      'errori. Verifica le informazioni importanti.';

  /// Variante compatta per gli schermi dei companion (watch).
  static const assistantAiDisclosureShort =
      'Risposte generate da IA: possono contenere errori.';

  /// Optimized GLB mascots for **phone** UI only (see `assets/mesh-3d/`).
  /// Watch / Wear / Garmin / Fitbit companions stay 2D-text lightweight —
  /// no model_viewer WebView on those surfaces.
  /// - [assistantGlb]: chat / FAB avatar (tennis-ball mascot)
  /// - [tipGlb]: coach tip / lavagna (tip mascot variant)
  static const assistantGlb = 'assets/mesh-3d/pallino.glb';
  static const tipGlb = 'assets/mesh-3d/pallino_tip.glb';
}
