/// Voce manuale (PRD D3): push-to-talk, ascolto 4s, comando chiuso,
/// conferma aptica. NESSUN ascolto continuo in background (PRD 5.2).
///
/// Comandi riconosciuti (it):
///   "punto noi" / "noi"            → punto Team A
///   "punto loro" / "loro"          → punto Team B
///   "punto team a" / "punto team b"
///   "annulla" / "indietro"         → undo
///   "pausa"                        → pausa
///   "riprendi"                     → riprendi
///   "fine partita"                 → termina
library;

import 'package:speech_to_text/speech_to_text.dart';

enum VoiceCommand { pointUs, pointThem, undo, pause, resume, finish }

enum VoiceFailure {
  unavailable,
  permissionDenied,
  busy,
  timeout,
  recognitionError,
  noMatch,
}

class VoiceScoring {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _busy = false;
  String? _lastError;

  VoiceFailure? lastFailure;
  String lastTranscript = '';

  Future<bool> init() async {
    if (_available) return true;
    _lastError = null;
    _available = await _speech.initialize(
      onError: (error) => _lastError = error.errorMsg,
      options: [SpeechToText.androidNoBluetooth],
    );
    return _available;
  }

  bool get isListening => _speech.isListening;

  /// Ascolta per ~4 secondi e ritorna il comando riconosciuto (o null).
  Future<VoiceCommand?> listenOnce() async {
    if (_busy || _speech.isListening) {
      lastFailure = VoiceFailure.busy;
      return null;
    }
    _busy = true;
    lastFailure = null;
    lastTranscript = '';
    _lastError = null;

    try {
      if (!_available && !await init()) {
        lastFailure = await _speech.hasPermission
            ? VoiceFailure.unavailable
            : VoiceFailure.permissionDenied;
        return null;
      }

      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: 'it_IT',
          listenFor: const Duration(seconds: 4),
          pauseFor: const Duration(milliseconds: 1300),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.confirmation,
        ),
        onResult: (result) => lastTranscript = result.recognizedWords,
      );

      // listen() avvia la sessione e ritorna subito. Il limite esterno evita
      // che un recognizer di sistema difettoso mantenga la UI bloccata.
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (_speech.isListening && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      if (_speech.isListening) {
        lastFailure = VoiceFailure.timeout;
      }
      await _speech.stop();

      final command = parse(lastTranscript);
      if (command == null) {
        lastFailure = _lastError == null
            ? (lastFailure ?? VoiceFailure.noMatch)
            : VoiceFailure.recognitionError;
      }
      return command;
    } on ListenFailedException {
      lastFailure = VoiceFailure.recognitionError;
      return null;
    } on SpeechToTextNotInitializedException {
      _available = false;
      lastFailure = VoiceFailure.unavailable;
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> cancel() => _speech.cancel();

  /// Parser deterministico e testabile.
  static VoiceCommand? parse(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;
    if (t.contains('annulla') ||
        t.contains('annullo') ||
        t.contains('indietro') ||
        t.contains('cancella') ||
        t.contains('correggi')) {
      return VoiceCommand.undo;
    }
    if (t.contains('fine partita') ||
        t.contains('termina') ||
        t.contains('chiudi partita') ||
        t.contains('stop partita')) {
      return VoiceCommand.finish;
    }
    if (t.contains('riprendi')) return VoiceCommand.resume;
    if (t.contains('pausa')) return VoiceCommand.pause;
    if (t.contains('team a')) return VoiceCommand.pointUs;
    if (t.contains('team b')) return VoiceCommand.pointThem;
    if (t.contains('noi') ||
        t.contains('punto mio') ||
        t.contains('a noi') ||
        t.contains('per noi') ||
        t.contains('nostro') ||
        t.contains('nostri')) {
      return VoiceCommand.pointUs;
    }
    if (t.contains('loro') ||
        t.contains('punto avversario') ||
        t.contains('a loro') ||
        t.contains('per loro') ||
        t.contains('avversari') ||
        t.contains('avversario')) {
      return VoiceCommand.pointThem;
    }
    return null;
  }
}
