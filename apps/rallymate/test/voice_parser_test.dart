import 'package:flutter_test/flutter_test.dart';
import 'package:rallymate/services/voice_scoring.dart';

void main() {
  group('VoiceScoring.parse (PRD D3)', () {
    test('punto noi/loro', () {
      expect(VoiceScoring.parse('punto noi'), VoiceCommand.pointUs);
      expect(VoiceScoring.parse('Punto Loro'), VoiceCommand.pointThem);
      expect(VoiceScoring.parse('punto team a'), VoiceCommand.pointUs);
      expect(VoiceScoring.parse('punto team b'), VoiceCommand.pointThem);
      expect(
        VoiceScoring.parse('punto agli avversari'),
        VoiceCommand.pointThem,
      );
      expect(VoiceScoring.parse('questo è nostro'), VoiceCommand.pointUs);
      expect(VoiceScoring.parse('punto mio'), VoiceCommand.pointUs);
      expect(VoiceScoring.parse('punto avversario'), VoiceCommand.pointThem);
    });

    test('annulla, pausa, riprendi, fine partita', () {
      expect(VoiceScoring.parse('annulla'), VoiceCommand.undo);
      expect(VoiceScoring.parse('torna indietro'), VoiceCommand.undo);
      expect(VoiceScoring.parse('cancella ultimo punto'), VoiceCommand.undo);
      expect(VoiceScoring.parse('pausa'), VoiceCommand.pause);
      expect(VoiceScoring.parse('riprendi'), VoiceCommand.resume);
      expect(VoiceScoring.parse('fine partita'), VoiceCommand.finish);
      expect(VoiceScoring.parse('chiudi partita'), VoiceCommand.finish);
    });

    test('rumore → null', () {
      expect(VoiceScoring.parse(''), isNull);
      expect(VoiceScoring.parse('che bella giornata'), isNull);
    });
  });
}
