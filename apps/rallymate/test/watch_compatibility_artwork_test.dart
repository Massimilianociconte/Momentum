import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/watch_compatibility.dart';

void main() {
  test('every onboarding family references a bundled wearable artwork', () {
    final config =
        jsonDecode(
              File('assets/config/watch_compatibility.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final families = (config['families'] as List<dynamic>)
        .map(
          (value) => WatchFamily.fromJson(
            (value as Map<dynamic, dynamic>).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);

    expect(families, isNotEmpty);
    for (final family in families) {
      expect(
        family.artworkAsset,
        startsWith('assets/onboarding/wearables/'),
        reason: family.id,
      );
      expect(File(family.artworkAsset).existsSync(), isTrue, reason: family.id);
    }
  });

  test('wearable artwork keeps the responsive 4:3 budget', () async {
    final config =
        jsonDecode(
              File('assets/config/watch_compatibility.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final families = (config['families'] as List<dynamic>)
        .map(
          (value) => WatchFamily.fromJson(
            (value as Map<dynamic, dynamic>).cast<String, Object?>(),
          ),
        )
        .toList(growable: false);

    for (final family in families) {
      final file = File(family.artworkAsset);
      expect(
        file.lengthSync(),
        lessThan(100 * 1024),
        reason: '${family.id} exceeds the onboarding image budget',
      );

      final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 960, reason: family.id);
      expect(frame.image.height, 720, reason: family.id);
      final rgba = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(rgba, isNotNull, reason: family.id);
      final bytes = rgba!.buffer.asUint8List();
      final width = frame.image.width;
      final height = frame.image.height;
      final cornerAlphaOffsets = <int>[
        3,
        ((width - 1) * 4) + 3,
        (((height - 1) * width) * 4) + 3,
        ((((height - 1) * width) + width - 1) * 4) + 3,
      ];
      for (final offset in cornerAlphaOffsets) {
        expect(
          bytes[offset],
          0,
          reason: '${family.id} must blend into the onboarding background',
        );
      }
      frame.image.dispose();
      codec.dispose();
    }
  });
}
