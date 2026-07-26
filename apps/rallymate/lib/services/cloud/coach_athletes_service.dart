/// Modulo Coach — gestione atleti, assegnazione schede, progress tracking e
/// profilo pubblico (PRD I1/I4, migration 20260713120000).
///
/// Il coach si collega agli atleti con un codice personale a 8 caratteri
/// (stile Duo). Le schede sono jsonb su coach_assignments: il coach scrive il
/// piano, l'atleta aggiorna SOLO progressi/feedback (trigger server-side).
library;

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_service.dart';

const _netTimeout = Duration(seconds: 12);
const _timeoutMessage = 'Rete lenta o assente. Riprova.';

SupabaseClient? get _client => cloudClient;

/// Atleta collegato al coach, con avanzamento schede (RPC my_coach_athletes).
class CoachAthlete {
  const CoachAthlete({
    required this.athleteId,
    required this.displayName,
    required this.level,
    required this.role,
    required this.assignmentsTotal,
    required this.assignmentsCompleted,
    this.avatarUrl,
    this.lastProgressAt,
  });

  final String athleteId;
  final String displayName;
  final String level;
  final String role;
  final int assignmentsTotal;
  final int assignmentsCompleted;
  final String? avatarUrl;
  final DateTime? lastProgressAt;

  static CoachAthlete fromRow(Map<String, dynamic> r) {
    final nickname = r['nickname'] as String? ?? '';
    final name = r['name'] as String? ?? '';
    return CoachAthlete(
      athleteId: r['athlete_id'] as String,
      displayName: nickname.isNotEmpty ? nickname : name,
      level: r['level'] as String? ?? '',
      role: r['preferred_role'] as String? ?? 'UNDEFINED',
      assignmentsTotal: (r['assignments_total'] as num?)?.toInt() ?? 0,
      assignmentsCompleted: (r['assignments_completed'] as num?)?.toInt() ?? 0,
      avatarUrl: r['avatar_url'] as String?,
      lastProgressAt: DateTime.tryParse(r['last_progress_at'] as String? ?? ''),
    );
  }
}

/// Coach collegato, lato atleta (RPC my_coaches).
class MyCoach {
  const MyCoach({
    required this.coachId,
    required this.displayName,
    required this.club,
    required this.verified,
    this.avatarUrl,
  });

  final String coachId;
  final String displayName;
  final String club;
  final bool verified;
  final String? avatarUrl;

  static MyCoach fromRow(Map<String, dynamic> r) {
    final nickname = r['nickname'] as String? ?? '';
    final name = r['name'] as String? ?? '';
    return MyCoach(
      coachId: r['coach_id'] as String,
      displayName: nickname.isNotEmpty ? nickname : name,
      club: r['club'] as String? ?? '',
      verified: r['verified'] as bool? ?? false,
      avatarUrl: r['avatar_url'] as String?,
    );
  }
}

/// Scheda assegnata (coach_assignments). training_plan/progress sono jsonb.
class CoachAssignment {
  const CoachAssignment({
    required this.assignmentId,
    required this.coachId,
    required this.playerId,
    required this.status,
    required this.plan,
    required this.progress,
    required this.feedback,
    required this.updatedAt,
  });

  final String assignmentId;
  final String coachId;
  final String playerId;
  final String status; // ASSIGNED | IN_PROGRESS | COMPLETED | EXPIRED
  final Map<String, dynamic> plan;
  final Map<String, dynamic> progress;
  final String feedback;
  final DateTime? updatedAt;

  String get title => plan['title'] as String? ?? 'Scheda allenamento';
  String get notes => plan['notes'] as String? ?? '';
  int get sessionsTarget => (plan['sessionsTarget'] as num?)?.toInt() ?? 1;
  List<Map<String, dynamic>> get drills => (plan['drills'] as List? ?? const [])
      .map((d) => (d as Map).cast<String, dynamic>())
      .toList();

  int get sessionsDone => (progress['sessionsDone'] as num?)?.toInt() ?? 0;
  int get minutesDone => (progress['minutes'] as num?)?.toInt() ?? 0;
  String get athleteNote => progress['athleteNote'] as String? ?? '';

  double get completion =>
      sessionsTarget == 0 ? 0 : (sessionsDone / sessionsTarget).clamp(0, 1);

  static CoachAssignment fromRow(Map<String, dynamic> r) => CoachAssignment(
    assignmentId: r['assignment_id'] as String,
    coachId: r['coach_id'] as String,
    playerId: r['player_id'] as String,
    status: r['status'] as String? ?? 'ASSIGNED',
    plan: ((r['training_plan'] as Map?) ?? const {}).cast<String, dynamic>(),
    progress: ((r['progress'] as Map?) ?? const {}).cast<String, dynamic>(),
    feedback: r['feedback'] as String? ?? '',
    updatedAt: DateTime.tryParse(r['updated_at'] as String? ?? ''),
  );
}

/// Profilo coach pubblico (PRD I1, RPC coach_public_profile).
class CoachPublicProfile {
  const CoachPublicProfile({
    required this.coachId,
    required this.displayName,
    required this.bio,
    required this.club,
    required this.certifications,
    required this.specializations,
    required this.verified,
    required this.ratingAvg,
    required this.ratingCount,
    required this.packages,
    this.avatarUrl,
  });

  final String coachId;
  final String displayName;
  final String bio;
  final String club;
  final List<String> certifications;
  final List<String> specializations;
  final bool verified;
  final double ratingAvg;
  final int ratingCount;
  final List<Map<String, dynamic>> packages;
  final String? avatarUrl;

  static CoachPublicProfile fromJson(
    Map<String, dynamic> j,
  ) => CoachPublicProfile(
    coachId: j['coachId'] as String,
    displayName: j['nickname'] as String? ?? '',
    bio: j['bio'] as String? ?? '',
    club: j['club'] as String? ?? '',
    certifications: (j['certifications'] as List? ?? const []).cast<String>(),
    specializations: (j['specializations'] as List? ?? const []).cast<String>(),
    verified: j['verified'] as bool? ?? false,
    ratingAvg: double.tryParse(j['ratingAvg'].toString()) ?? 0,
    ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
    packages: (j['packages'] as List? ?? const [])
        .map((p) => (p as Map).cast<String, dynamic>())
        .toList(),
    avatarUrl: j['avatarUrl'] as String?,
  );
}

typedef CoachActionResult = ({
  bool ok,
  String? error,
  Map<String, dynamic> data,
});

class CoachAthletesService {
  static bool get available => _client != null;
  static String? get currentUserId => _client?.auth.currentUser?.id;

  static String _translate(String? code) => switch (code) {
    'auth_required' => 'Accedi prima al tuo account.',
    'coach_required' => 'Il codice atleti richiede il piano Coach.',
    'invalid_code' => 'Il codice ha 8 caratteri.',
    'not_found' => 'Nessun coach trovato con questo codice.',
    'self_link' => 'Non puoi collegarti a te stesso.',
    'rate_limited' => 'Troppi tentativi: riprova tra qualche minuto.',
    'not_available' => 'Operazione non disponibile.',
    'not_allowed' => 'Operazione non consentita.',
    'athlete_not_available' => 'Atleta non disponibile.',
    'athlete_not_linked' => 'Atleta non collegato al tuo profilo Coach.',
    'purchase_not_valid' => 'Acquisto non valido per questo atleta.',
    'invalid_training_plan' => 'Scheda di allenamento non valida.',
    'retry' => 'Riprova: generazione codice non riuscita.',
    _ => 'Operazione non riuscita. Riprova.',
  };

  static Future<CoachActionResult> _rpc(
    String fn, [
    Map<String, dynamic>? params,
  ]) async {
    final c = _client;
    if (c == null) {
      return (
        ok: false,
        error: 'Servizi online non disponibili.',
        data: const <String, dynamic>{},
      );
    }
    try {
      final raw = await c.rpc(fn, params: params).timeout(_netTimeout);
      final map = (raw as Map).cast<String, dynamic>();
      if (map['ok'] == true) return (ok: true, error: null, data: map);
      return (ok: false, error: _translate(map['error'] as String?), data: map);
    } on TimeoutException {
      return (
        ok: false,
        error: _timeoutMessage,
        data: const <String, dynamic>{},
      );
    } on PostgrestException catch (e) {
      return (ok: false, error: e.message, data: const <String, dynamic>{});
    } catch (_) {
      return (
        ok: false,
        error: 'Operazione non riuscita.',
        data: const <String, dynamic>{},
      );
    }
  }

  // ---- link coach <-> atleta

  static Future<CoachActionResult> myLinkCode() => _rpc('my_coach_link_code');

  static Future<CoachActionResult> joinCoach(String code) =>
      _rpc('join_coach', {'p_code': code});

  static Future<CoachActionResult> endLink({
    required String coachId,
    required String athleteId,
  }) => _rpc('end_coach_link', {
    'p_coach_id': coachId,
    'p_athlete_id': athleteId,
  });

  static Future<List<CoachAthlete>> athletes() async {
    final c = _client;
    if (c == null || c.auth.currentUser == null) return const [];
    final rows = await c.rpc('my_coach_athletes').timeout(_netTimeout);
    return (rows as List)
        .map((r) => CoachAthlete.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<List<MyCoach>> myCoaches() async {
    final c = _client;
    if (c == null || c.auth.currentUser == null) return const [];
    final rows = await c.rpc('my_coaches').timeout(_netTimeout);
    return (rows as List)
        .map((r) => MyCoach.fromRow((r as Map).cast<String, dynamic>()))
        .toList();
  }

  // ---- profilo coach

  static Future<CoachPublicProfile?> publicProfile(String coachId) async {
    final result = await _rpc('coach_public_profile', {'p_coach_id': coachId});
    if (!result.ok) return null;
    return CoachPublicProfile.fromJson(result.data);
  }

  /// Aggiorna il profilo pubblico del coach (I1: bio, club, certificazioni,
  /// specializzazioni). Upsert: il profilo nasce alla prima modifica.
  static Future<String?> updateMyProfile({
    required String bio,
    required String club,
    required List<String> certifications,
    required List<String> specializations,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return 'Accedi prima al tuo account';
    try {
      await c
          .from('coach_profiles')
          .upsert({
            'coach_id': uid,
            'bio': bio.trim(),
            'club': club.trim(),
            'certifications': certifications,
            'specializations': specializations,
          })
          .timeout(_netTimeout);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return 'Salvataggio non riuscito';
    }
  }

  // ---- assegnazioni schede

  /// Lato coach: tutte le assegnazioni, opzionalmente di un solo atleta.
  static Future<List<CoachAssignment>> coachAssignments({
    String? athleteId,
  }) async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    var query = c.from('coach_assignments').select().eq('coach_id', uid);
    if (athleteId != null) query = query.eq('player_id', athleteId);
    final rows = await query
        .order('created_at', ascending: false)
        .timeout(_netTimeout);
    return rows.map(CoachAssignment.fromRow).toList();
  }

  /// Lato atleta: schede ricevute.
  static Future<List<CoachAssignment>> myAssignments() async {
    final c = _client;
    final uid = c?.auth.currentUser?.id;
    if (c == null || uid == null) return const [];
    final rows = await c
        .from('coach_assignments')
        .select()
        .eq('player_id', uid)
        .neq('status', 'EXPIRED')
        .order('created_at', ascending: false)
        .timeout(_netTimeout);
    return rows.map(CoachAssignment.fromRow).toList();
  }

  static Future<String?> assignTraining({
    required String athleteId,
    required String title,
    required String notes,
    required int sessionsTarget,
    required List<Map<String, dynamic>> drills,
  }) async {
    final result = await _rpc('assign_coach_training', {
      'p_player_id': athleteId,
      'p_training_plan': {
        'title': title.trim(),
        'notes': notes.trim(),
        'sessionsTarget': sessionsTarget,
        'drills': drills,
      },
    });
    return result.ok ? null : result.error;
  }

  /// Lato atleta: registra una sessione completata (progress tracking I4).
  static Future<String?> logAssignmentSession({
    required CoachAssignment assignment,
    required int minutes,
    String? note,
  }) async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    final sessionsDone = assignment.sessionsDone + 1;
    final completed = sessionsDone >= assignment.sessionsTarget;
    try {
      await c
          .from('coach_assignments')
          .update({
            'progress': {
              ...assignment.progress,
              'sessionsDone': sessionsDone,
              'minutes': assignment.minutesDone + minutes,
              'lastAt': DateTime.now().toUtc().toIso8601String(),
              if (note != null && note.trim().isNotEmpty)
                'athleteNote': note.trim(),
            },
            'status': completed ? 'COMPLETED' : 'IN_PROGRESS',
          })
          .eq('assignment_id', assignment.assignmentId)
          .timeout(_netTimeout);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return 'Aggiornamento non riuscito';
    }
  }

  /// Lato coach: feedback sulla scheda (I4 "feedback progressi").
  static Future<String?> setAssignmentFeedback({
    required String assignmentId,
    required String feedback,
  }) async {
    final c = _client;
    if (c == null) return 'Servizi online non disponibili.';
    try {
      await c
          .from('coach_assignments')
          .update({'feedback': feedback.trim()})
          .eq('assignment_id', assignmentId)
          .timeout(_netTimeout);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } on TimeoutException {
      return _timeoutMessage;
    } catch (_) {
      return 'Salvataggio non riuscito';
    }
  }
}
