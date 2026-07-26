library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../services/team_image_service.dart';
import 'theme.dart';
import 'widgets.dart';

class TeamAvatar extends ConsumerWidget {
  const TeamAvatar({
    super.key,
    required this.team,
    this.size = 48,
    this.heroTag,
  });

  final Team team;
  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = Semantics(
      image: true,
      label: 'Immagine del team ${team.name}',
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: _TeamImage(
            team: team,
            fit: BoxFit.cover,
            fallback: _TeamFallback(team: team),
          ),
        ),
      ),
    );
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: avatar);
  }
}

/// Efficient score surface: images are decoded at a bounded size and covered
/// by a static contrast gradient. No live blur is used during scoring.
class TeamScoringSurface extends StatelessWidget {
  const TeamScoringSurface({
    super.key,
    required this.team,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.semanticLabel,
    this.onLongPress,
    this.borderRadius = 28,
  });

  final Team? team;
  final Widget child;
  final VoidCallback onTap;
  final bool enabled;
  final String? semanticLabel;
  final VoidCallback? onLongPress;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final selectedTeam = team;
    final color = selectedTeam == null
        ? RallyColors.lime
        : Color(selectedTeam.colorArgb);
    final hasImage =
        selectedTeam != null &&
        (selectedTeam.imageLocalPath?.isNotEmpty == true ||
            selectedTeam.imageCloudPath?.isNotEmpty == true);
    final useImage =
        selectedTeam != null &&
        hasImage &&
        selectedTeam.scoringStyle != 'COLOR';

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              color: color.withValues(alpha: 0.18),
              border: Border.all(color: color.withValues(alpha: 0.62)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius - 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (useImage)
                    _TeamImage(
                      team: selectedTeam,
                      fit: BoxFit.cover,
                      fallback: const SizedBox.shrink(),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: useImage
                            ? const [Color(0x8A05070B), Color(0xD905070B)]
                            : [
                                color.withValues(alpha: 0.16),
                                RallyColors.night.withValues(alpha: 0.52),
                              ],
                      ),
                    ),
                  ),
                  IconTheme(
                    data: const IconThemeData(color: Colors.white),
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(color: Colors.white),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamImage extends ConsumerWidget {
  const _TeamImage({
    required this.team,
    required this.fit,
    required this.fallback,
  });

  final Team team;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPath = team.imageLocalPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          cacheWidth: 640,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      }
    }
    if (team.imageCloudPath?.isNotEmpty != true) return fallback;
    return SignedUrlImage(
      objectPath: team.imageCloudPath,
      resolve: ref.read(teamImageServiceProvider).signedUrl,
      builder: (url) {
        if (url == null || url.isEmpty) return fallback;
        return Image.network(
          url,
          fit: fit,
          cacheWidth: 640,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }
}

class _TeamFallback extends StatelessWidget {
  const _TeamFallback({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final color = Color(team.colorArgb);
    final words = team.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word.substring(0, 1).toUpperCase())
        .join();
    return ColoredBox(
      color: color.withValues(alpha: 0.18),
      child: Center(
        child: initials.isEmpty
            ? Icon(Icons.groups, color: color)
            : Text(
                initials,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
