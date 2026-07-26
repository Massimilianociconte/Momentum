/// Maps Padelandia drill names to bundled vertical demo videos.
library;

/// Returns an asset path for a drill demo video when available.
String? trainingVideoForDrill(String drillName) {
  final n = drillName.toLowerCase();
  if (n.contains('vol') || n.contains('rete') || n.contains('controllo')) {
    return 'assets/videos/drill_volley.mp4';
  }
  if (n.contains('lob') || n.contains('difens')) {
    return 'assets/videos/drill_lob.mp4';
  }
  if (n.contains('bandeja') || n.contains('vibora') || n.contains('smash') ||
      n.contains('chiusura')) {
    return 'assets/videos/drill_bandeja.mp4';
  }
  if (n.contains('riscaldamento') || n.contains('footwork') || n.contains('gambe')) {
    return 'assets/videos/onboarding_play.mp4';
  }
  // Generic padel technique fallback.
  return 'assets/videos/drill_volley.mp4';
}

const onboardingPlayVideo = 'assets/videos/onboarding_play.mp4';
