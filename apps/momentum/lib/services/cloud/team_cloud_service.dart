library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../data/db/database.dart';
import 'cloud_service.dart';

/// Reconciles accepted cloud memberships into the offline-first team store.
/// The cloud UUID prevents duplicate teams after repeated invite redemption.
class TeamCloudService {
  TeamCloudService(this.ref);

  final Ref ref;
  bool _syncing = false;
  bool _syncingOwned = false;

  Future<void> syncOwnedMetadata() async {
    if (_syncingOwned || cloudClient?.auth.currentUser == null) return;
    _syncingOwned = true;
    try {
      final teams = await ref.read(teamRepoProvider).all();
      for (final team in teams) {
        if (team.cloudRole == 'OWNER' && team.cloudId?.isNotEmpty == true) {
          await syncOwnedTeam(team);
        }
      }
    } finally {
      _syncingOwned = false;
    }
  }

  Future<String?> syncOwnedTeam(Team team) async {
    final client = cloudClient;
    if (client?.auth.currentUser == null || team.cloudRole == 'MEMBER') {
      return null;
    }
    try {
      final result = await client!
          .rpc(
            'upsert_cloud_team',
            params: {
              'p_local_id': team.id,
              'p_name': team.name,
              'p_scoring_style': team.scoringStyle,
              'p_color_argb': team.colorArgb,
              'p_visibility': 'PRIVATE',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (result is! String || result.isEmpty) {
        return 'Team cloud non disponibile.';
      }
      await ref
          .read(teamRepoProvider)
          .linkCloudTeam(id: team.id, cloudId: result);
      return null;
    } on TimeoutException {
      return 'Modifica salvata sul telefono; sync cloud in attesa.';
    } on PostgrestException catch (error) {
      return error.message;
    } on Exception {
      return 'Modifica salvata sul telefono; sync cloud non riuscita.';
    }
  }

  Future<String?> syncMemberships() async {
    final client = cloudClient;
    if (_syncing || client?.auth.currentUser == null) return null;
    _syncing = true;
    try {
      final me = await ref.read(playerRepoProvider).me();
      if (me == null) return 'Completa prima il profilo locale.';
      final response = await client!
          .rpc('my_cloud_teams')
          .timeout(const Duration(seconds: 12));
      final rows = ((response as List?) ?? const [])
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
      final active = <String>{};
      final repository = ref.read(teamRepoProvider);
      for (final row in rows) {
        final cloudId = row['team_id'] as String?;
        final name = (row['name'] as String?)?.trim() ?? '';
        if (cloudId == null || name.isEmpty) continue;
        active.add(cloudId);
        await repository.importCloudMembership(
          cloudId: cloudId,
          name: name,
          playerAId: me.id,
          cloudRole: row['cloud_role'] as String? ?? 'MEMBER',
          ownerName: row['owner_name'] as String? ?? '',
          avatarPath: row['avatar_path'] as String?,
          imageVersion: (row['image_version'] as num?)?.toInt() ?? 0,
          scoringStyle: row['scoring_style'] as String? ?? 'AUTO',
          colorArgb: (row['color_argb'] as num?)?.toInt() ?? 0xFFC8F135,
        );
      }
      await repository.reconcileCloudMemberships(active);
      return null;
    } on TimeoutException {
      return 'Sincronizzazione team in attesa della rete.';
    } on PostgrestException catch (error) {
      return error.message;
    } on Exception {
      return 'Sincronizzazione team non riuscita.';
    } finally {
      _syncing = false;
    }
  }
}

final teamCloudServiceProvider = Provider(TeamCloudService.new);
