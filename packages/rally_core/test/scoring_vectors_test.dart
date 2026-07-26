/// Drift guard: il file wear/shared/scoring_vectors.json committato deve
/// restare identico a ciò che l'engine Dart produce oggi. Se l'engine cambia
/// comportamento, rigenerare con:
///
///     dart run tool/generate_scoring_vectors.dart
///
/// e far girare i runner di conformità Kotlin/Swift/Fitbit.
library;

import 'dart:convert';

import 'package:test/test.dart';

import '../tool/generate_scoring_vectors.dart' as generator;

void main() {
  test('scoring_vectors.json è allineato all\'engine rally_core', () {
    final file = generator.sharedVectorsFile();
    expect(
      file.existsSync(),
      isTrue,
      reason: 'Manca ${file.path}: eseguire il generatore.',
    );
    final committed = jsonDecode(file.readAsStringSync());
    final expected = jsonDecode(jsonEncode(generator.buildVectorsDocument()));
    expect(
      committed,
      equals(expected),
      reason:
          'Vettori non aggiornati: dart run '
          'tool/generate_scoring_vectors.dart',
    );
  });

  test('ogni vettore dichiara piattaforme e almeno uno step', () {
    final doc = generator.buildVectorsDocument();
    final vectors = doc['vectors'] as List;
    expect(vectors, isNotEmpty);
    for (final raw in vectors) {
      final vector = raw as Map<String, Object?>;
      expect(vector['platforms'], isNotEmpty, reason: '${vector['id']}');
      expect((vector['steps'] as List), isNotEmpty, reason: '${vector['id']}');
    }
  });
}
