/// Match formats (PRD C2).
library;

/// Fully describes how a padel match is scored.
///
/// Presets cover: set classico con vantaggi, golden point, tie-break,
/// super tie-break come terzo set, meglio di 3, partita secca,
/// allenamento libero e formati custom.
class MatchFormat {
  const MatchFormat({
    required this.id,
    required this.name,
    this.setsToWin = 2,
    this.gamesPerSet = 6,
    this.goldenPoint = true,
    this.tieBreakAtGamesAll = true,
    this.tieBreakPoints = 7,
    this.superTieBreakDecider = false,
    this.superTieBreakPoints = 10,
    this.freePlay = false,
  }) : assert(setsToWin >= 1 && setsToWin <= 3),
       assert(gamesPerSet >= 1);

  /// Stable identifier, part of the sync protocol.
  final String id;
  final String name;

  /// Sets needed to win the match (2 = best of 3, 1 = one set / secca).
  final int setsToWin;

  /// Games needed to win a set (with 2-game margin, else tie-break).
  final int gamesPerSet;

  /// True = punto de oro at deuce (no-ad, FIP standard). False = vantaggi.
  final bool goldenPoint;

  /// Tie-break at gamesPerSet-all (e.g. 6-6).
  final bool tieBreakAtGamesAll;
  final int tieBreakPoints;

  /// Replace the deciding set with a super tie-break.
  final bool superTieBreakDecider;
  final int superTieBreakPoints;

  /// Allenamento libero: rally point counting only, no games/sets.
  final bool freePlay;

  /// FIP standard: best of 3, golden point, tie-break at 6-6.
  static const goldenPointBo3 = MatchFormat(
    id: 'GOLDEN_BO3',
    name: 'Golden point — meglio di 3',
  );

  /// Traditional advantage scoring, best of 3.
  static const advantageBo3 = MatchFormat(
    id: 'ADV_BO3',
    name: 'Vantaggi — meglio di 3',
    goldenPoint: false,
  );

  /// Best of 3 with a 10-point super tie-break instead of the third set.
  static const superTieBreakBo3 = MatchFormat(
    id: 'SUPER_TB_BO3',
    name: 'Super tie-break al terzo',
    superTieBreakDecider: true,
  );

  /// One-set match (partita secca).
  static const singleSet = MatchFormat(
    id: 'SINGLE_SET',
    name: 'Partita secca — 1 set',
    setsToWin: 1,
  );

  /// Free training: only counts points.
  static const training = MatchFormat(
    id: 'TRAINING',
    name: 'Allenamento libero',
    setsToWin: 1,
    freePlay: true,
  );

  static const presets = <MatchFormat>[
    goldenPointBo3,
    advantageBo3,
    superTieBreakBo3,
    singleSet,
    training,
  ];

  /// Total sets that can be played.
  int get maxSets => setsToWin * 2 - 1;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'setsToWin': setsToWin,
    'gamesPerSet': gamesPerSet,
    'goldenPoint': goldenPoint,
    'tieBreakAtGamesAll': tieBreakAtGamesAll,
    'tieBreakPoints': tieBreakPoints,
    'superTieBreakDecider': superTieBreakDecider,
    'superTieBreakPoints': superTieBreakPoints,
    'freePlay': freePlay,
  };

  factory MatchFormat.fromJson(Map<String, Object?> json) => MatchFormat(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Custom',
    setsToWin: json['setsToWin'] as int? ?? 2,
    gamesPerSet: json['gamesPerSet'] as int? ?? 6,
    goldenPoint: json['goldenPoint'] as bool? ?? true,
    tieBreakAtGamesAll: json['tieBreakAtGamesAll'] as bool? ?? true,
    tieBreakPoints: json['tieBreakPoints'] as int? ?? 7,
    superTieBreakDecider: json['superTieBreakDecider'] as bool? ?? false,
    superTieBreakPoints: json['superTieBreakPoints'] as int? ?? 10,
    freePlay: json['freePlay'] as bool? ?? false,
  );
}
