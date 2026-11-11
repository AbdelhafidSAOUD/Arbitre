// Génère supabase/seed.sql à partir de assets/content/*.json.
//
//   dart run tool/generate_seed.dart
//
// Le contenu embarqué dans l'application et celui du serveur restent ainsi
// identiques. Le script est rejouable : les questions existantes sont mises
// à jour, pas dupliquées.
import 'dart:convert';
import 'dart:io';

String sql(String? s) => s == null ? 'null' : "'${s.replaceAll("'", "''")}'";
String jsonb(Object v) => "${sql(jsonEncode(v))}::jsonb";

void main() {
  final questions = jsonDecode(File('assets/content/questions.json').readAsStringSync()) as List;
  final lessons = jsonDecode(File('assets/content/lessons.json').readAsStringSync()) as List;
  final b = StringBuffer()
    ..writeln('-- Fichier généré par tool/generate_seed.dart : ne pas modifier à la main.')
    ..writeln('-- ${questions.length} questions, ${lessons.length} fiches.')
    ..writeln()
    ..writeln('insert into public.questions (id, law, kind, difficulty, role_tag, question, options, answer_index, explanation, laws_edition) values');
  b.writeln([
    for (final q in questions.cast<Map<String, dynamic>>())
      '  (${sql(q['id'])}, ${q['law']}, ${sql(q['kind'])}, ${q['difficulty']}, ${sql(q['role_tag'])}, '
          '${sql(q['question'])}, ${jsonb(q['options'])}, ${q['answer_index']}, ${sql(q['explanation'])}, ${sql(q['laws_edition'])})',
  ].join(',\n'));
  b
    ..writeln('on conflict (id) do update set')
    ..writeln('  law = excluded.law, kind = excluded.kind, difficulty = excluded.difficulty, role_tag = excluded.role_tag,')
    ..writeln('  question = excluded.question, options = excluded.options, answer_index = excluded.answer_index,')
    ..writeln('  explanation = excluded.explanation, laws_edition = excluded.laws_edition, active = true;')
    ..writeln()
    ..writeln('insert into public.lessons (law, title, points) values');
  b.writeln([
    for (final l in lessons.cast<Map<String, dynamic>>()) '  (${l['law']}, ${sql(l['title'])}, ${jsonb(l['points'])})',
  ].join(',\n'));
  b.writeln('on conflict (law) do update set title = excluded.title, points = excluded.points;');
  File('supabase/seed.sql').writeAsStringSync(b.toString());
  stdout.writeln('supabase/seed.sql : ${questions.length} questions, ${lessons.length} fiches.');
}
