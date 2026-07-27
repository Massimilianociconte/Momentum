// Genera il corpo SQL di seed per rules_faq dal dataset Dart
// (fonte unica: lib/src/rules/rules_data.dart).
//
//     dart run tool/generate_faq_seed.dart
//
// L'output va incollato in una migration forward: le migration già applicate
// non vanno mai riscritte. La migration deve anche cancellare gli id non più
// presenti nel dataset (vedi la lista `keep` in coda all'output).
import 'package:rally_core/rally_core.dart';

String esc(String s) => s.replaceAll("'", "''");

String sqlText(String? value) => value == null ? 'null' : "'${esc(value)}'";

void main() {
  final b = StringBuffer()
    ..writeln('-- Seed FAQ regolamento (generato da rally_core '
        'tool/generate_faq_seed.dart — non modificare a mano).')
    ..writeln('-- Edizione: $padelRulesEdition (versione $padelRulesVersion).')
    ..writeln();
  for (final r in padelRules) {
    final keywords = '{${r.keywords.map((k) => '"${esc(k)}"').join(',')}}';
    b.writeln(
        'insert into public.rules_faq (id, question, answer, keywords, '
        'source, rule_ref, rules_version, example, lang) values (');
    b.writeln("  '${esc(r.id)}',");
    b.writeln("  '${esc(r.question)}',");
    b.writeln("  '${esc(r.answer)}',");
    b.writeln("  '$keywords',");
    b.writeln("  '${esc(r.source)}',");
    b.writeln('  ${sqlText(r.ruleRef)},');
    b.writeln("  '${esc(padelRulesVersion)}',");
    b.writeln('  ${sqlText(r.example)},');
    b.writeln("  'it'");
    b.writeln(') on conflict (id) do update set');
    b.writeln('  question = excluded.question, answer = excluded.answer,');
    b.writeln('  keywords = excluded.keywords, source = excluded.source,');
    b.writeln('  rule_ref = excluded.rule_ref,');
    b.writeln('  rules_version = excluded.rules_version,');
    b.writeln('  example = excluded.example, updated_at = now();');
    b.writeln();
  }

  final keep = padelRules.map((r) => "'${esc(r.id)}'").join(', ');
  b
    ..writeln('-- Rimuove le voci non più presenti nel dataset locale.')
    ..writeln('delete from public.rules_faq where lang = \'it\'')
    ..writeln('  and id not in ($keep);');

  print(b);
}
