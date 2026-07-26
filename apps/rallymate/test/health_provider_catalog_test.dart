import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/domain/health_provider.dart';

void main() {
  final config =
      jsonDecode(
            File(
              'assets/config/health_provider_compatibility.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final providers = (config['providers'] as List<dynamic>)
      .map(
        (value) => HealthProviderDescriptor.fromJson(
          (value as Map<dynamic, dynamic>).cast<String, Object?>(),
        ),
      )
      .toList(growable: false);

  test('public catalog never advertises research or unsupported providers', () {
    for (final provider in providers.where((value) => value.isPublic)) {
      expect(
        provider.support,
        isNot(
          anyOf(
            HealthProviderSupportStatus.research,
            HealthProviderSupportStatus.notSupported,
          ),
        ),
        reason: provider.id,
      );
      expect(provider.sourceUrl.isScheme('https'), isTrue, reason: provider.id);
    }
  });

  test('direct cloud providers stay rollout-disabled until approval', () {
    for (final id in ['OURA_DIRECT', 'WHOOP_DIRECT']) {
      final provider = providers.singleWhere((value) => value.id == id);
      expect(provider.rollout, HealthRolloutState.disabled, reason: id);
      expect(provider.requiresPremium, isTrue, reason: id);
      expect(provider.capabilities.supportsCloudOAuth, isTrue, reason: id);
    }
  });

  test('health-only providers never claim scoring support', () {
    for (final provider in providers) {
      expect(
        provider.capabilities.supportsScoringApp,
        isFalse,
        reason: provider.id,
      );
    }
  });

  test('availability never impersonates an authorized connection', () {
    const available = HealthProviderConnectionStatus(
      providerId: 'HEALTH_CONNECT',
      state: 'AVAILABLE',
      authorizedMetrics: {},
    );
    const connected = HealthProviderConnectionStatus(
      providerId: 'HEALTH_CONNECT',
      state: 'CONNECTED',
      authorizedMetrics: {HealthMetricType.heartRate},
    );

    expect(available.available, isTrue);
    expect(available.connected, isFalse);
    expect(connected.available, isTrue);
    expect(connected.connected, isTrue);
  });

  test(
    'every published health artwork is 4:3 with transparent corners',
    () async {
      final withArtwork = providers.where(
        (provider) =>
            provider.support.canHavePublicArtwork &&
            provider.artworkAsset.startsWith('assets/onboarding/health/'),
      );

      for (final provider in withArtwork) {
        final file = File(provider.artworkAsset);
        expect(file.existsSync(), isTrue, reason: provider.id);
        expect(file.lengthSync(), lessThan(600 * 1024), reason: provider.id);
        final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 960, reason: provider.id);
        expect(frame.image.height, 720, reason: provider.id);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(rgba, isNotNull, reason: provider.id);
        final bytes = rgba!.buffer.asUint8List();
        final width = frame.image.width;
        final height = frame.image.height;
        for (final offset in [
          3,
          ((width - 1) * 4) + 3,
          (((height - 1) * width) * 4) + 3,
          ((((height - 1) * width) + width - 1) * 4) + 3,
        ]) {
          expect(bytes[offset], 0, reason: provider.id);
        }
        var transparentPixels = 0;
        var opaqueWhitePixels = 0;
        var opaqueEdgePixels = 0;
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final offset = (y * width + x) * 4;
            final red = bytes[offset];
            final green = bytes[offset + 1];
            final blue = bytes[offset + 2];
            final alpha = bytes[offset + 3];
            if (alpha == 0) transparentPixels++;
            if (alpha > 220 && red > 245 && green > 245 && blue > 245) {
              opaqueWhitePixels++;
            }
            final inEdgeBand =
                x < 24 || x >= width - 24 || y < 24 || y >= height - 24;
            if (inEdgeBand && alpha > 4) opaqueEdgePixels++;
          }
        }
        expect(
          transparentPixels / (width * height),
          greaterThan(0.75),
          reason: '${provider.id}: the artwork must not carry a backdrop',
        );
        expect(
          opaqueWhitePixels,
          0,
          reason: '${provider.id}: opaque white label/background detected',
        );
        expect(
          opaqueEdgePixels,
          0,
          reason: '${provider.id}: artwork reaches the safe-area edge',
        );
        frame.image.dispose();
        codec.dispose();
      }
    },
  );
}
