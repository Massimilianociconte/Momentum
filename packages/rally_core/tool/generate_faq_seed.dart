// Genera la migration SQL di seed per rules_faq dal dataset Dart
// (fonte unica: lib/src/rules/rules_data.dart).
import 'package:rally_core/rally_core.dart';

String esc(String s) => s.replaceAll("'", "''");

void main() {
  final b = StringBuffer()
    ..writeln('-- Seed FAQ regolamento (generato da rally_core '
        'tool/generate_faq_seed.dart — non modificare a mano).')
    ..writeln();
  for (final r in padelRules) {
    final keywords =
        '{${r.keywords.map((k) => '"${esc(k)}"').join(',')}}';
    b.writeln(
        "insert into public.rules_faq (id, question, answer, keywords, source, example, lang) values (");
    b.writeln("  '${esc(r.id)}',");
    b.writeln("  '${esc(r.question)}',");
    b.writeln("  '${esc(r.answer)}',");
    b.writeln("  '$keywords',");
    b.writeln("  '${esc(r.source)}',");
    b.writeln(
        r.example == null ? '  null,' : "  '${esc(r.example!)}',");
    b.writeln("  'it'");
    b.writeln(') on conflict (id) do update set');
    b.writeln('  question = excluded.question, answer = excluded.answer,');
    b.writeln('  keywords = excluded.keywords, source = excluded.source,');
    b.writeln('  example = excluded.example, updated_at = now();');
    b.writeln();
  }
  print(b);
}
