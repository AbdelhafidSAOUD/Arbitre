import 'package:material_ui/material_ui.dart';

import '../logic/offside.dart';
import '../models/content.dart';
import '../theme.dart';
import 'common.dart';
import 'pitch.dart';
import 'quiz_screen.dart';

void openLesson(BuildContext context, int law) {
  AppScope.read(context).markLessonRead(law);
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => LessonScreen(law: law)));
}

class LearnTab extends StatelessWidget {
  const LearnTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    return PageList(children: [
      const Headline(
        eyebrow: 'Formation',
        title: 'Parcours des 17 lois',
        subtitle: 'Des fiches courtes, puis un quiz pour valider chaque loi à 75 %.',
      ),
      for (final t in tracks) ...[
        const SizedBox(height: 22),
        Builder(builder: (context) {
          final valid = t.laws.where((l) => (s.lawPercent(l) ?? 0) >= 75).length;
          final seen = t.laws.map(s.lawPercent).whereType<int>().toList();
          final avg = seen.isEmpty ? null : (seen.reduce((a, b) => a + b) / seen.length).round();
          return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
                Text(t.description, style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
            Pill('$valid/${t.laws.length} validée${valid > 1 ? 's' : ''}', tone: toneForPercent(avg)),
          ]);
        }),
        const SizedBox(height: 10),
        ListBox(children: [
          for (final l in t.laws)
            Row2(
              leading: LawNumber(l),
              title: lawName(l),
              subtitle: '${s.content.lessons[l]?.points.length ?? 0} points clés${s.data.readLessons.containsKey(l) ? ' · lue' : ''}',
              trailing: Pill(
                s.lawPercent(l) == null
                    ? 'À découvrir'
                    : s.lawPercent(l)! >= 75
                        ? 'Validée'
                        : '${s.lawPercent(l)} %',
                tone: toneForPercent(s.lawPercent(l)),
              ),
              onTap: () => openLesson(context, l),
            ),
        ]),
      ],
    ]);
  }
}

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.law});
  final int law;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  OffsideScenario example = generateOffside();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final l = widget.law;
    final lesson = s.content.lessons[l];
    final p = s.lawPercent(l);
    final n = s.content.countForLaw(l);
    return Scaffold(
      appBar: AppBar(title: Eyebrow('Loi $l')),
      body: PageList(children: [
        Text(lawName(l).toUpperCase(), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 16),
        Panel(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('L’essentiel à retenir', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final point in lesson?.points ?? const <String>[])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 8,
                    height: 11,
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(2)),
                  ),
                  Expanded(child: Text(point, style: const TextStyle(height: 1.45))),
                ]),
              ),
          ]),
        ),
        if (l == 11) ...[
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exemple au moment de la passe', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              OffsidePitch(scenario: example, reveal: true),
              const SizedBox(height: 10),
              Text(example.explanation, style: const TextStyle(fontSize: 14, height: 1.45)),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => setState(() => example = generateOffside()), child: const Text('Autre exemple')),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Votre maîtrise', style: TextStyle(color: c.muted))),
          Pill(p == null ? 'Pas encore évaluée' : '$p %', tone: toneForPercent(p)),
        ]),
        const SizedBox(height: 16),
        if (n > 0)
          FilledButton(
            onPressed: () => startQuiz(context, s.configFor('law', law: l)),
            child: const Text('Me tester sur cette loi'),
          ),
        const SizedBox(height: 16),
        Text(
          'Résumé pédagogique. Le texte de référence reste les Lois du Jeu de l’IFAB, édition en vigueur, '
          'et les directives de votre fédération.',
          style: TextStyle(fontSize: 13, color: c.muted),
        ),
      ]),
    );
  }
}
