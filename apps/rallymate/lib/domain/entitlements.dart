/// Freemium plans and feature gates (PRD 8).
///
/// The free tier must cost ~zero to serve: everything local, no LLM, no
/// cloud backup. Revenue features are gated here in ONE place so margins
/// stay under control. Billing is store-based (IAP) via RevenueCat — this
/// class only mirrors the entitlement state.
library;

enum Plan {
  free('Free', 0),
  plus('Plus', 4.99),
  pro('Pro', 8.99),
  coach('Coach', 14.99);

  const Plan(this.label, this.monthlyEur);
  final String label;
  final double monthlyEur;

  static Plan fromName(String? n) =>
      Plan.values.firstWhere((p) => p.name == n, orElse: () => Plan.free);
}

class Entitlements {
  const Entitlements(this.plan, {this.premiumOverride = false});
  final Plan plan;

  /// Test/admin bypass (PRD 8 + Duo Mode §11): sblocca le feature premium
  /// senza acquisto reale. Impostato SOLO da: profiles.premium_override sul
  /// backend, account_role admin, o flag di build RALLYMATE_TEST_PREMIUM.
  /// Tenuto separato da [plan] così i log e le metriche di conversione
  /// distinguono i tester dai paganti.
  final bool premiumOverride;

  // ---- limits (Free)
  static const freeMaxTeams = 3; // acceptance criteria: almeno 3 team free
  static const freeWrappedPerWeek = 1;
  static const proAssistantDailyQuestions = 20;
  static const proAssistantLiveMatchQuestions = 5;

  bool get isPaid => plan != Plan.free;

  bool hasAtLeast(Plan required) =>
      premiumOverride || plan.index >= required.index;

  int get maxTeams => (premiumOverride || isPaid) ? 1 << 30 : freeMaxTeams;

  /// Plus+: analytics avanzate, trend, per-ruolo/per-partner (PRD F2).
  bool get premiumAnalytics => hasAtLeast(Plan.plus);

  /// Plus+: backup cloud e sync multi-device.
  bool get cloudBackup => hasAtLeast(Plan.plus);

  /// Plus+: Padelandia Wrapped illimitato + link pubblici + export PDF.
  bool get unlimitedWrapped => hasAtLeast(Plan.plus);

  /// Plus+: allenamenti premium.
  bool get premiumTraining => hasAtLeast(Plan.plus);

  /// Pro+: Mascot Assistant con LLM e fonti verificate (PRD E4).
  bool get llmAssistant => hasAtLeast(Plan.pro);

  /// Plus+: export PDF dei report (PRD 8 Plus + H2).
  bool get pdfExport => hasAtLeast(Plan.plus);

  /// Pro+: statistiche avanzate per difficoltà avversari — upset, imprese,
  /// miglior vittoria / peggior sconfitta (PRD F5).
  bool get advancedDifficulty => hasAtLeast(Plan.pro);

  /// Pro+: gruppi amici con classifiche private (PRD 8 Pro).
  bool get friendGroups => hasAtLeast(Plan.pro);

  /// Pro+: integrazione fitness avanzata con Apple Salute / Google Health
  /// Connect (PRD J).
  bool get healthConnectSync => hasAtLeast(Plan.pro);

  /// Coach: pacchetti, atleti, marketplace (PRD Modulo I).
  bool get coachTools => premiumOverride || plan == Plan.coach;

  /// Plus+ (o override test/admin): Duo Mode — due smartwatch, uno per team,
  /// segnano la stessa partita.
  bool get duoMode => hasAtLeast(Plan.plus);
}

/// What a gate should show when locked.
class GateInfo {
  const GateInfo({required this.requiredPlan, required this.pitch});
  final Plan requiredPlan;
  final String pitch;
}

const gates = <String, GateInfo>{
  'premium_analytics': GateInfo(
    requiredPlan: Plan.plus,
    pitch:
        'Clutch score, momentum, rendimento per ruolo e per partner, trend '
        'settimanali e mensili.',
  ),
  'llm_assistant': GateInfo(
    requiredPlan: Plan.pro,
    pitch:
        'Pallino Assistant: fonti verificate, form partite, allenamenti e '
        'chimica team/coppie (senza dati salute di sistema).',
  ),
  'coach_tools': GateInfo(
    requiredPlan: Plan.coach,
    pitch: 'Crea pacchetti, assegna schede, monitora i tuoi atleti.',
  ),
  'health_connect': GateInfo(
    requiredPlan: Plan.pro,
    pitch:
        'Integra passi, calorie attive e frequenza cardiaca da Apple Salute '
        'o Google Health Connect nei riepiloghi fitness.',
  ),
  'duo_mode': GateInfo(
    requiredPlan: Plan.plus,
    pitch:
        'Con Duo Mode ogni team può segnare i propri punti dal proprio '
        'smartwatch, con sincronizzazione automatica della partita tra '
        'compagni e avversari connessi.',
  ),
  'pdf_export': GateInfo(
    requiredPlan: Plan.plus,
    pitch:
        'Esporta il report della tua stagione in PDF: stats, trend e '
        'imprese pronti da condividere o stampare.',
  ),
  'difficulty_advanced': GateInfo(
    requiredPlan: Plan.pro,
    pitch:
        'Upset win e loss, streak contro pari livello, miglior vittoria e '
        'peggior sconfitta: le tue imprese misurate sul livello avversari.',
  ),
  'friend_groups': GateInfo(
    requiredPlan: Plan.pro,
    pitch:
        'Crea gruppi con i tuoi amici e sfidali in classifiche private: '
        'vittorie, win rate e streak a confronto.',
  ),
};
