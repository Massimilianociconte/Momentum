/// RFC 4122 version 4 identifiers used as cross-device event idempotency keys.
library;

import 'dart:math';

final Random _eventIdRandom = Random.secure();

/// Generates a canonical lowercase UUID v4 without a platform prefix.
///
/// Event IDs are opaque: replay continues to accept legacy identifiers, while
/// every newly-created event uses the same wire shape on phone and wearables.
String generateEventId() {
  final bytes = List<int>.generate(
    16,
    (_) => _eventIdRandom.nextInt(256),
    growable: false,
  );
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String pair(int value) => value.toRadixString(16).padLeft(2, '0');
  final hex = bytes.map(pair).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
