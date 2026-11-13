import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../logic/dates.dart';
import '../logic/exam_case.dart';
import '../models/content.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Questions au format examen : cocher toutes les décisions à prendre.
Future<void> openExamCases(BuildContext context, {int count = 5, String? onlyId}) {
  final s = AppScope.read(context);
  final all = s.content.examCases;
  final picked = onlyId != null
      ? all.where((c) => c.id == onlyId).toList()
      : (List.of(all)..shuffle(s.rng)).take(min(count, all.length)).toList();
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExamCasesScreen(cases: picked), fullscreenDialog: true));
}

class ExamCasesScreen extends StatefulWidget {
  const ExamCasesScreen({super.key, required this.cases});
  final List<ExamCase> cases;
  @override
  State<ExamCasesScreen> createState() => _ExamCasesScreenState();
}

class _ExamCasesScreenState extends State<ExamCasesScreen> {
  int index = 0;
  Set<int> picked = {};
  bool checked = false;
  double points = 0;
  bool done = false;

  ExamCase get q => widget.cases[index];

  void _check() {
    setState(() {
      checked = true;
      points += q.score(picked);
    });
  }

  void _next() {
    if (index + 1 < widget.cases.length) {
      setState(() {
        index++;
        picked = {};
        checked = false;
      });
      return;
    }
    // Enregistré en quarts de point, comme la notation de l'examen.
    AppScope.read(context).recordScoredSession(Labels.examCases, (points * 4).round(), widget.cases.length * 4);
    setState(() => done = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    if (widget.cases.isEmpty) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Aucun cas disponible.')));
    }
    if (done) {
      final note = 20 * points / widget.cases.length;
      return Scaffold(
        appBar: AppBar(title: const Text('Format examen')),
        body: PageList(children: [
          Headline(eyebrow: 'Résultat', title: '${frNumber(note)} / 20'),
          const SizedBox(height: 12),
          const Text('Comme à l’examen, chaque élément oublié ou en trop (motif, rapport, reprise) retire 0,25 point à la question.'),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Terminer')),
        ]),
      );
    }
    final score = checked ? q.score(picked) : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text('Cas ${index + 1} / ${widget.cases.length}')),
      body: PageList(children: [
        Text('Loi ${q.law} · ${lawName(q.law)}', style: TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w700, fontSize: 16, color: c.pitch)),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: Pill(q.source, tone: q.source.contains('FFF') ? Tone.mid : Tone.none)),
        const SizedBox(height: 10),
        Panel(child: Text(q.situation, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35))),
        const SizedBox(height: 10),
        Text('Décisions ? Cochez tout ce que l’arbitre doit faire, sans oublier le motif ni le rapport.',
            style: TextStyle(fontSize: 13, color: c.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DecisionTile(
              label: q.options[i],
              selected: picked.contains(i),
              state: !checked
                  ? null
                  : q.answers.contains(i)
                      ? (picked.contains(i) ? 'ok' : 'missed')
                      : (picked.contains(i) ? 'extra' : null),
              onTap: checked ? null : () => setState(() => picked.contains(i) ? picked.remove(i) : picked.add(i)),
            ),
          ),
        const SizedBox(height: 6),
        if (checked) ...[
          Panel(
            color: c.surface2,
            borderColor: score == 1 ? c.pitch : c.red,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${frNumber(score, decimals: 2)} / 1 point', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(q.explanation),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _next, child: Text(index + 1 < widget.cases.length ? 'Cas suivant' : 'Voir ma note')),
        ] else
          FilledButton(onPressed: picked.isEmpty ? null : _check, child: const Text('Valider mes décisions')),
      ]),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.label, required this.selected, required this.state, required this.onTap});
  final String label;
  final bool selected;
  final String? state; // ok | missed | extra
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final (bg, border, note) = switch (state) {
      'ok' => (c.pitchSoft, c.pitch, 'Juste'),
      'missed' => (c.surface, c.pitch, 'Oublié'),
      'extra' => (c.redSoft, c.red, 'En trop'),
      _ => (selected ? c.pitchSoft : c.surface, selected ? c.pitch : c.line, null),
    };
    return Semantics(
      checked: selected,
      label: note == null ? label : '$label, $note',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: border, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: selected ? c.pitch : c.muted),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (note != null) Text(note, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: border)),
            ]),
          ),
        ),
      ),
    );
  }
}
