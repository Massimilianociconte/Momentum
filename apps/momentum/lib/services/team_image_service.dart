/// Team image pipeline: picker -> native crop -> bounded JPEG -> app support.
/// Cloud upload is optional and only attempted for entitled signed-in users.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../data/db/database.dart';
import 'cloud/cloud_service.dart';

enum TeamImageSource { gallery, camera }

class TeamImageResult {
  const TeamImageResult({
    required this.saved,
    this.cancelled = false,
    this.cloudSynced = false,
    this.message,
  });

  final bool saved;
  final bool cancelled;
  final bool cloudSynced;
  final String? message;
}

class TeamImageService {
  TeamImageService(this.ref);

  final Ref ref;
  final _picker = ImagePicker();
  final Map<String, ({String url, DateTime expires})> _signedUrlCache = {};
  bool _syncingPending = false;

  static const _bucket = 'team-avatars';
  static const _maxBytes = 2 * 1024 * 1024;

  bool get _profileLinked => ref.read(cloudAuthProvider).profileLinked;

  Future<TeamImageResult> pickAndSave(Team team, TeamImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source == TeamImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null) {
        return const TeamImageResult(saved: false, cancelled: true);
      }
      return _cropAndPersist(team, picked.path);
    } on Exception {
      return const TeamImageResult(
        saved: false,
        message: 'Non è stato possibile aprire la foto. Controlla i permessi.',
      );
    }
  }

  /// Android can recreate the activity while the system picker is open.
  Future<TeamImageResult?> recoverLostSelection(Team team) async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;
      final file = lost.file;
      if (file == null) {
        return TeamImageResult(
          saved: false,
          message: lost.exception?.message ?? 'Foto non recuperabile.',
        );
      }
      return _cropAndPersist(team, file.path);
    } on Exception {
      return const TeamImageResult(
        saved: false,
        message: 'Recupero della foto non riuscito.',
      );
    }
  }

  Future<TeamImageResult> _cropAndPersist(Team team, String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: 640,
      maxHeight: 640,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 82,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Immagine del team',
          toolbarColor: const Color(0xFF0C1220),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFC8F135),
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Immagine del team',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: false,
          doneButtonTitle: 'Usa foto',
          cancelButtonTitle: 'Annulla',
        ),
      ],
    );
    if (cropped == null) {
      return const TeamImageResult(saved: false, cancelled: true);
    }

    final temporary = File(cropped.path);
    if (!await temporary.exists() ||
        await temporary.length() == 0 ||
        await temporary.length() > _maxBytes ||
        !await _isJpeg(temporary)) {
      return const TeamImageResult(
        saved: false,
        message: 'L’immagine non è valida oppure è troppo grande.',
      );
    }

    final support = await getApplicationSupportDirectory();
    final safeId = team.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final folder = Directory('${support.path}/team_images/$safeId');
    await folder.create(recursive: true);
    final destination = File(
      '${folder.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await temporary.copy(destination.path);

    final oldPath = team.imageLocalPath;
    await ref
        .read(teamRepoProvider)
        .updateAppearance(id: team.id, localImagePath: destination.path);
    await _deleteManagedFile(oldPath, support.path);

    final current = await ref.read(teamRepoProvider).byId(team.id);
    if (current == null) {
      return const TeamImageResult(
        saved: false,
        message: 'Il team non è più disponibile.',
      );
    }
    final shouldSyncCloud =
        _profileLinked &&
        cloudClient?.auth.currentUser != null &&
        ref.read(entitlementsProvider).cloudBackup;
    final cloud = shouldSyncCloud
        ? await _syncToCloud(current, destination)
        : null;
    return TeamImageResult(
      saved: true,
      cloudSynced: !shouldSyncCloud || cloud == null,
      message: cloud,
    );
  }

  Future<String?> _syncToCloud(Team team, File image) async {
    final client = cloudClient;
    final auth = client?.auth.currentUser;
    final entitled = ref.read(entitlementsProvider).cloudBackup;
    if (!_profileLinked || client == null || auth == null || !entitled) {
      return 'Foto salvata sul telefono. Cloud in attesa del piano e dell’accesso.';
    }

    try {
      final cloudTeamId = await ensureCloudTeam(team, client: client);
      final objectPath = '${auth.id}/$cloudTeamId/avatar.jpg';
      await client.storage
          .from(_bucket)
          .upload(
            objectPath,
            image,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              cacheControl: '3600',
            ),
          )
          .timeout(const Duration(seconds: 15));
      final updated = await client
          .rpc(
            'set_team_avatar',
            params: {'p_team_id': cloudTeamId, 'p_avatar_path': objectPath},
          )
          .timeout(const Duration(seconds: 12));
      if (updated != true) throw const FormatException('Team cloud mancante');
      await ref
          .read(teamRepoProvider)
          .markImageCloudSynced(
            id: team.id,
            imageVersion: team.imageVersion,
            cloudImagePath: objectPath,
          );
      _signedUrlCache.remove(objectPath);
      return null;
    } on TimeoutException {
      return 'Foto salvata sul telefono. La sincronizzazione cloud sarà riprovata.';
    } on StorageException catch (error) {
      return 'Foto salvata sul telefono. Cloud: ${error.message}';
    } on PostgrestException catch (error) {
      return 'Foto salvata sul telefono. Cloud: ${error.message}';
    } on Exception {
      return 'Foto salvata sul telefono. Sincronizzazione cloud non riuscita.';
    }
  }

  Future<String> ensureCloudTeam(Team team, {SupabaseClient? client}) async {
    final selectedClient = client ?? cloudClient;
    if (!_profileLinked || selectedClient?.auth.currentUser == null) {
      throw StateError('Accedi prima al tuo account');
    }
    if (team.cloudId?.isNotEmpty == true) return team.cloudId!;
    final result = await selectedClient!
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
      throw const FormatException('UUID team cloud non valido');
    }
    await ref
        .read(teamRepoProvider)
        .linkCloudTeam(id: team.id, cloudId: result);
    return result;
  }

  Future<void> remove(Team team) async {
    final support = await getApplicationSupportDirectory();
    await _deleteManagedFile(team.imageLocalPath, support.path);
    await ref
        .read(teamRepoProvider)
        .updateAppearance(id: team.id, removeImage: true);
    final current = await ref.read(teamRepoProvider).byId(team.id);
    if (current == null) return;
    await _syncRemoval(current, team.imageCloudPath);
  }

  Future<String?> _syncRemoval(Team team, String? previousCloudPath) async {
    final client = cloudClient;
    if (previousCloudPath == null || previousCloudPath.isEmpty) {
      await ref
          .read(teamRepoProvider)
          .markImageCloudSynced(
            id: team.id,
            imageVersion: team.imageVersion,
            cloudImagePath: null,
          );
      return null;
    }
    if (!_profileLinked || client?.auth.currentUser == null) {
      return 'Rimozione cloud in attesa del prossimo accesso.';
    }
    try {
      await client!.storage
          .from(_bucket)
          .remove([previousCloudPath])
          .timeout(const Duration(seconds: 15));
      if (team.cloudId?.isNotEmpty == true) {
        await client
            .rpc(
              'set_team_avatar',
              params: {'p_team_id': team.cloudId, 'p_avatar_path': ''},
            )
            .timeout(const Duration(seconds: 12));
      }
      await ref
          .read(teamRepoProvider)
          .markImageCloudSynced(
            id: team.id,
            imageVersion: team.imageVersion,
            cloudImagePath: null,
          );
      _signedUrlCache.remove(previousCloudPath);
      return null;
    } on Exception {
      return 'Rimozione cloud in attesa di sincronizzazione.';
    }
  }

  /// Replays image uploads/deletions after sign-in, app resume or a transient
  /// network failure. Version comparison makes retries idempotent.
  Future<void> syncPending() async {
    if (_syncingPending ||
        !_profileLinked ||
        cloudClient?.auth.currentUser == null) {
      return;
    }
    _syncingPending = true;
    try {
      final entitled = ref.read(entitlementsProvider).cloudBackup;
      final teams = await ref.read(teamRepoProvider).all();
      for (final team in teams) {
        if (team.imageCloudVersion >= team.imageVersion) continue;
        final localPath = team.imageLocalPath;
        final local = localPath == null ? null : File(localPath);
        if (local != null && await local.exists()) {
          if (entitled) await _syncToCloud(team, local);
        } else {
          await _syncRemoval(team, team.imageCloudPath);
        }
      }
    } finally {
      _syncingPending = false;
    }
  }

  Future<String?> signedUrl(String? objectPath) async {
    if (!_profileLinked ||
        objectPath == null ||
        objectPath.isEmpty ||
        cloudClient == null) {
      return null;
    }
    final cached = _signedUrlCache[objectPath];
    if (cached != null && cached.expires.isAfter(DateTime.now())) {
      return cached.url;
    }
    try {
      final url = await cloudClient!.storage
          .from(_bucket)
          .createSignedUrl(objectPath, 3600);
      _signedUrlCache[objectPath] = (
        url: url,
        expires: DateTime.now().add(const Duration(minutes: 50)),
      );
      return url;
    } on Exception {
      return null;
    }
  }

  Future<bool> _isJpeg(File file) async {
    final bytes = await file
        .openRead(0, 3)
        .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  Future<void> _deleteManagedFile(String? path, String supportPath) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.path.startsWith('$supportPath/team_images/')) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Old cache cleanup must never break a successful replacement.
    }
  }
}

final teamImageServiceProvider = Provider(TeamImageService.new);
