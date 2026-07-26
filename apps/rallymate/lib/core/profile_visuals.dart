library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../services/profile_image_service.dart';
import 'theme.dart';
import 'widgets.dart';

class PlayerAvatar extends ConsumerWidget {
  const PlayerAvatar({
    super.key,
    required this.player,
    this.size = 56,
    this.semanticLabel = 'Foto profilo',
  });

  final Player? player;
  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPath = player?.avatarLocalPath;
    final localFile = localPath == null ? null : File(localPath);
    final localAvailable = localFile?.existsSync() ?? false;
    final avatar = localAvailable
        ? _image(FileImage(localFile!))
        : SignedUrlImage(
            objectPath: player?.avatarCloudPath,
            resolve: ref.read(profileImageServiceProvider).signedUrl,
            builder: (url) =>
                url == null ? _fallback() : _image(NetworkImage(url)),
          );

    return Semantics(
      image: true,
      label: semanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: avatar),
      ),
    );
  }

  Widget _image(ImageProvider provider) => Image(
    image: ResizeImage.resizeIfNeeded((size * 3).round(), null, provider),
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _fallback(),
  );

  Widget _fallback() {
    final name =
        (player?.nickname.isNotEmpty == true
                ? player!.nickname
                : (player?.name ?? 'R'))
            .trim();
    final initial = name.isEmpty ? 'R' : name.characters.first.toUpperCase();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D2D3F), Color(0xFF070B16)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            color: RallyColors.lime,
          ),
        ),
      ),
    );
  }
}
