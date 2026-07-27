/// Esporta il dataset regole di rally_core per la landing.
///
///     dart run tool/generate_web_rules.dart
///
/// Output: apps/momentum-web/src/content/generated/padel-rules.json
///
/// Perché passare da qui invece di riscrivere le regole nel sito: il dataset
/// Dart è già verificato riga per riga sulle FIP Rules of Padel (revisione
/// 01.01.2026) e porta numero di regola ed edizione. Duplicarlo a mano
/// significherebbe avere due verità che divergono al primo aggiornamento
/// regolamentare — esattamente il problema che l'audit aveva trovato tra app
/// e knowledge base cloud.
library;

import 'dart:convert';
import 'dart:io';

import 'package:rally_core/rally_core.dart';

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (Directory('${dir.path}/apps/momentum-web').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Cartella apps/momentum-web non trovata sopra $dir');
    }
    dir = parent;
  }
}

/// Raggruppa le voci in sezioni tematiche: una pagina con 36 domande in fila
/// non è navigabile, e i motori generativi citano meglio blocchi con un
/// titolo che dichiara l'argomento.
const _sections = <String, (String, String, List<String>)>{
  'punteggio': (
    'Punteggio e formati',
    'Come si contano i punti, le tre opzioni FIP sulla parità e i formati di partita ammessi dal regolamento.',
    [
      'scoring_base',
      'star_point',
      'golden_point',
      'tie_break',
      'super_tie_break',
      'mini_set',
      'match_tie_break_7',
      'third_set_no_tiebreak',
    ],
  ),
  'servizio': (
    'Servizio e risposta',
    'Come si batte, quando è fallo, quando si ripete e in che ordine si serve e si riceve.',
    [
      'serve_choice',
      'serve_how',
      'serve_fault',
      'serve_let',
      'serve_order',
      'receive_order',
      'receive_position',
    ],
  ),
  'gioco': (
    'Palla in gioco, pareti e griglie',
    'Cosa si può fare con vetri e griglie, quando il punto è perso e quando la risposta è valida.',
    [
      'walls_own_side',
      'smash_return_own_side',
      'grid',
      'double_bounce',
      'net_touch',
      'over_net_reach',
      'out_of_court',
      'smash_out',
      'ball_hits_player',
      'double_hit',
    ],
  ),
  'situazioni': (
    'Situazioni di gara',
    'Cambio campo, let, interferenza, cordino di sicurezza e cambio delle palle.',
    [
      'change_sides',
      'let_point',
      'interference',
      'safety_cord',
      'ball_change',
      'who_calls',
    ],
  ),
  'tempi': (
    'Tempi, campo e attrezzatura',
    'Riscaldamento e pause, misure del campo, racchetta e palle, sospensioni e penalità.',
    [
      'warmup_time',
      'suspensions_medical',
      'penalties',
      'court_size',
      'racket_ball',
      'electronic_devices_tournaments',
    ],
  ),
};

void main() {
  final byId = {for (final rule in padelRules) rule.id: rule};
  final used = <String>{};

  final sections = <Map<String, Object?>>[];
  for (final entry in _sections.entries) {
    final (title, summary, ids) = entry.value;
    final items = <Map<String, Object?>>[];
    for (final id in ids) {
      final rule = byId[id];
      if (rule == null) {
        throw StateError('Regola "$id" assente da padelRules: sezione rotta.');
      }
      used.add(id);
      items.add({
        'id': rule.id,
        'question': rule.question,
        'answer': rule.answer,
        'source': rule.source,
        if (rule.ruleRef != null) 'ruleRef': rule.ruleRef,
        if (rule.example != null) 'example': rule.example,
        'citation': rule.citation,
        'keywords': rule.keywords,
      });
    }
    sections.add({
      'id': entry.key,
      'title': title,
      'summary': summary,
      'items': items,
    });
  }

  // Una regola nuova nel dataset che nessuno ha assegnato a una sezione
  // sparirebbe in silenzio dalla pagina: meglio far fallire la generazione.
  final orphans = padelRules.map((r) => r.id).where((id) => !used.contains(id));
  if (orphans.isNotEmpty) {
    throw StateError(
      'Regole senza sezione: ${orphans.join(', ')}. '
      'Aggiungile a _sections in tool/generate_web_rules.dart.',
    );
  }

  final document = {
    'version': padelRulesVersion,
    'edition': padelRulesEdition,
    'generator': 'packages/momentum_core/tool/generate_web_rules.dart',
    'note':
        'Generato da rally_core: non modificare a mano. La fonte unica è '
        'packages/momentum_core/lib/src/rules/rules_data.dart.',
    'sections': sections,
  };

  final file = File(
    '${_repoRoot().path}/apps/momentum-web/src/content/generated/'
    'padel-rules.json',
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(document)}\n',
  );
  final count = sections.fold<int>(
    0,
    (sum, s) => sum + (s['items']! as List).length,
  );
  stdout.writeln('Scritte $count regole in ${file.path}');
}
