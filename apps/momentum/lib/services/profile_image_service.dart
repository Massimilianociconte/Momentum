/// Personal portrait pipeline. The processed image is always written locally
/// first; private cloud storage is used only when cloud backup is entitled.
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
import 'watch_sync.dart';

enum ProfileImageSource { gallery, camera }

class ProfileImageResult {
  const ProfileImageResult({
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

class ProfileImageService {
  ProfileImageService(this.ref);

  final Ref ref;
  final _picker = ImagePicker();
  final Map<String, ({String url, DateTime expires})> _signedUrlCache = {};
  bool _syncing = false;

  static const _bucket = 'profile-avatars';
  static const _maxBytes = 2 * 1024 * 1024;

  bool get _profileLinked => ref.read(cloudAuthProvider).profileLinked;

  Future<ProfileImageResult> pickAndSave(
    Player player,
    ProfileImageSource source,
  ) async {
    try {
      final picked = await _picker.pickImage(
        source: source == ProfileImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 92,
      );
      if (picked == null) {
        return const ProfileImageResult(saved: false, cancelled: true);
      }
      return _cropAndPersist(player, picked.path);
    } on Exception {
      return const ProfileImageResult(
        saved: false,
        message: 'Non è stato possibile aprire la foto. Controlla i permessi.',
      );
    }
  }

  Future<ProfileImageResult?> recoverLostSelection(Player player) async {
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty) return null;
      final file = lost.file;
      if (file == null) {
        return ProfileImageResult(
          saved: false,
          message: lost.exception?.message ?? 'Foto non recuperabile.',
        );
      }
      return _cropAndPersist(player, file.path);
    } on Exception {
      return const ProfileImageResult(
        saved: false,
        message: 'Recupero della foto non riuscito.',
      );
    }
  }

  Future<ProfileImageResult> _cropAndPersist(
    Player player,
    String sourcePath,
  ) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      maxWidth: 640,
      maxHeight: 640,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 82,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Foto profilo',
          toolbarColor: const Color(0xFF0C1220),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFFC8F135),
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Foto profilo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          doneButtonTitle: 'Usa foto',
          cancelButtonTitle: 'Annulla',
        ),
      ],
    );
    if (cropped == null) {
      return const ProfileImageResult(saved: false, cancelled: true);
    }

    final temporary = File(cropped.path);
    if (!await _validJpeg(temporary)) {
      return const ProfileImageResult(
        saved: false,
        message: 'L’immagine non è valida oppure è troppo grande.',
      );
    }

    final support = await getApplicationSupportDirectory();
    final safeId = player.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final directory = Directory('${support.path}/profile_images/$safeId');
    await directory.create(recursive: true);
    final destination = File(
      '${directory.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await temporary.copy(destination.path);

    final oldPath = player.avatarLocalPath;
    await ref
        .read(playerRepoProvider)
        .updateAvatar(id: player.id, localPath: destination.path);
    await _deleteManagedFile(oldPath, support.path);

    final current = await ref.read(playerRepoProvider).me();
    if (current == null) {
      return const ProfileImageResult(
        saved: false,
        message: 'Il profilo non è più disponibile.',
      );
    }
    unawaited(
      ref
          .read(watchSyncProvider.notifier)
          .syncProfileImage(
            path: destination.path,
            version: current.avatarVersion,
          ),
    );
    final cloudAllowed =
        _profileLinked &&
        cloudClient?.auth.currentUser != null &&
        ref.read(entitlementsProvider).cloudBackup;
    final cloudError = cloudAllowed
        ? await _upload(current, destination)
        : null;
    return ProfileImageResult(
      saved: true,
      cloudSynced: cloudAllowed && cloudError == null,
      message:
          cloudError ??
          (cloudAllowed
              ? 'Foto salvata e sincronizzata.'
              : 'Foto salvata su questo dispositivo. Il backup multi-device richiede Premium.'),
    );
  }

  Future<String?> _upload(Player player, File image) async {
    final client = cloudClient;
    final user = client?.auth.currentUser;
    if (!_profileLinked || client == null || user == null) {
      return 'Accedi per sincronizzare la foto.';
    }
    if (!ref.read(entitlementsProvider).cloudBackup) {
      return 'Foto locale. Il backup multi-device richiede Premium.';
    }

    final objectPath = '${user.id}/avatar.jpg';
    try {
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
      await client
          .rpc('set_profile_avatar', params: {'p_avatar_path': objectPath})
          .timeout(const Duration(seconds: 12));
      await ref
          .read(playerRepoProvider)
          .markAvatarCloudSynced(
            id: player.id,
            version: player.avatarVersion,
            cloudPath: objectPath,
          );
      _signedUrlCache.remove(objectPath);
      return null;
    } on TimeoutException {
      return 'Foto locale al sicuro. La sincronizzazione sarà riprovata.';
    } on StorageException catch (error) {
      return 'Foto locale al sicuro. Cloud: ${error.message}';
    } on PostgrestException catch (error) {
      return 'Foto locale al sicuro. Cloud: ${error.message}';
    } on Exception {
      return 'Foto locale al sicuro. Sincronizzazione cloud non riuscita.';
    }
  }

  Future<String?> remove(Player player) async {
    final support = await getApplicationSupportDirectory();
    await _deleteManagedFile(player.avatarLocalPath, support.path);
    await ref
        .read(playerRepoProvider)
        .updateAvatar(
          id: player.id,
          cloudPath: player.avatarCloudPath,
          remove: true,
        );
    final current = await ref.read(playerRepoProvider).me();
    if (current == null) return null;
    unawaited(
      ref
          .read(watchSyncProvider.notifier)
          .syncProfileImage(path: null, version: current.avatarVersion),
    );
    return _removeCloud(current, player.avatarCloudPath);
  }

  Future<String?> _removeCloud(Player player, String? previousPath) async {
    final client = cloudClient;
    final user = client?.auth.currentUser;
    if (previousPath == null || previousPath.isEmpty) {
      await ref
          .read(playerRepoProvider)
          .markAvatarCloudSynced(
            id: player.id,
            version: player.avatarVersion,
            cloudPath: null,
          );
      return null;
    }
    if (!_profileLinked || client == null || user == null) {
      return 'Foto rimossa dal dispositivo. Rimozione cloud in attesa.';
    }
    try {
      await client.storage
          .from(_bucket)
          .remove([previousPath])
          .timeout(const Duration(seconds: 15));
      await client
          .rpc('set_profile_avatar', params: {'p_avatar_path': ''})
          .timeout(const Duration(seconds: 12));
      await ref
          .read(playerRepoProvider)
          .markAvatarCloudSynced(
            id: player.id,
            version: player.avatarVersion,
            cloudPath: null,
          );
      _signedUrlCache.remove(previousPath);
      return null;
    } on Exception {
      return 'Foto rimossa dal dispositivo. Rimozione cloud in attesa.';
    }
  }

  Future<void> syncPending() async {
    if (_syncing || !_profileLinked || cloudClient?.auth.currentUser == null) {
      return;
    }
    if (!ref.read(entitlementsProvider).cloudBackup) return;
    _syncing = true;
    try {
      final player = await ref.read(playerRepoProvider).me();
      if (player == null) return;
      final localPath = player.avatarLocalPath;
      final local = localPath == null ? null : File(localPath);
      if (player.avatarVersion > player.avatarCloudVersion) {
        if (local != null && await local.exists()) {
          await _upload(player, local);
        } else {
          await _removeCloud(player, player.avatarCloudPath);
        }
        return;
      }
      if (local != null && await local.exists()) return;
      await _restoreFromCloud(player);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _restoreFromCloud(Player player) async {
    final client = cloudClient;
    final user = client?.auth.currentUser;
    if (!_profileLinked || client == null || user == null) return;
    try {
      final profile = await client
          .from('profiles')
          .select('avatar_url')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 12));
      final objectPath = profile?['avatar_url'] as String?;
      if (objectPath == null ||
          objectPath.isEmpty ||
          objectPath.startsWith('http')) {
        return;
      }
      final bytes = await client.storage
          .from(_bucket)
          .download(objectPath)
          .timeout(const Duration(seconds: 15));
      if (bytes.isEmpty || bytes.length > _maxBytes) return;

      final support = await getApplicationSupportDirectory();
      final safeId = player.id.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final directory = Directory('${support.path}/profile_images/$safeId');
      await directory.create(recursive: true);
      final destination = File('${directory.path}/avatar_restored.jpg');
      await destination.writeAsBytes(bytes, flush: true);
      if (!await _validJpeg(destination)) {
        await destination.delete();
        return;
      }
      await ref
          .read(playerRepoProvider)
          .restoreAvatar(
            id: player.id,
            localPath: destination.path,
            cloudPath: objectPath,
          );
      unawaited(
        ref
            .read(watchSyncProvider.notifier)
            .syncProfileImage(
              path: destination.path,
              version: player.avatarVersion + 1,
            ),
      );
    } on Exception {
      // The next app resume retries; local profile editing remains available.
    }
  }

  Future<String?> signedUrl(String? objectPath) async {
    if (!_profileLinked ||
        objectPath == null ||
        objectPath.isEmpty ||
        cloudClient == null) {
      return null;
    }
    if (objectPath.startsWith('http')) return objectPath;
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

  Future<Map<String, String>> signedUrls(Iterable<String?> objectPaths) async {
    final paths = objectPaths
        .whereType<String>()
        .where((path) => path.isNotEmpty && !path.startsWith('http'))
        .toSet();
    final urls = <String, String>{};
    final missing = <String>[];
    for (final path in paths) {
      final cached = _signedUrlCache[path];
      if (cached != null && cached.expires.isAfter(DateTime.now())) {
        urls[path] = cached.url;
      } else {
        missing.add(path);
      }
    }
    if (missing.isEmpty || cloudClient == null) return urls;
    try {
      final signed = await cloudClient!.storage
          .from(_bucket)
          .createSignedUrlsResult(missing, 3600);
      for (final item in signed) {
        if (item is! SignedUrlSuccess) continue;
        urls[item.path] = item.signedUrl;
        _signedUrlCache[item.path] = (
          url: item.signedUrl,
          expires: DateTime.now().add(const Duration(minutes: 50)),
        );
      }
    } on Exception {
      // A blocked/private portrait simply falls back to initials.
    }
    return urls;
  }

  Future<bool> _validJpeg(File file) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length == 0 || length > _maxBytes) return false;
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
    if (!file.path.startsWith('$supportPath/profile_images/')) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Old cache cleanup must not invalidate the newly selected portrait.
    }
  }
}

final profileImageServiceProvider = Provider(ProfileImageService.new);
