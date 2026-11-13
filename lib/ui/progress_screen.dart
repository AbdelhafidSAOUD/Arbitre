import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../logic/progress.dart';
import '../models/content.dart';
import '../theme.dart';
import 'common.dart';
import '../state/app_state.dart';
import 'home_tab.dart';

/// Statistiques détaillées : maîtrise par loi, examens, exercices notés,
/// badges. Accessible depuis le profil.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final d = s.data;
    var total = 0, correct = 0;
    for (final t in d.laws.values) {
      total += t.total;
      correct += t.correct;
    }
    final acc = total == 0 ? 0 : (100 * correct / total).round();
    final exams = d.sessions.where((x) => x.isExam).toList().reversed.take(5).toList();
    final scored = d.sessions
        .where((x) => x.mode == Labels.examCases || x.mode == Labels.report)
        .toList()
        .reversed
        .take(6)
        .toList();

    Widget kpi(String value, String label) => Expanded(
          child: Panel(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontFamily: kDisplay, fontSize: 30, fontWeight: FontWeight.w800, height: 1, color: c.ink)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: c.muted, height: 1.2)),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ma progression')),
      body: PageList(children: [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kpi('$acc %', 'de bonnes décisions'),
            const SizedBox(width: 10),
            kpi(d.offside.percent == null ? '—' : '${d.offside.percent} %', 'hors-jeu bien jugés'),
            const SizedBox(width: 10),
            kpi('$total', 'questions traitées'),
          ]),
        ),
        const SectionTitle('Maîtrise par loi'),
        Panel(
          child: Column(children: [
            for (var l = 1; l <= 17; l++) _MasteryRow(law: l, percent: s.lawPercent(l)),
            const SizedBox(height: 4),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _legend(c.pitch, '75 % et plus : validée', c),
              _legend(c.card, '50–74 %', c),
              _legend(c.red, 'moins de 50 %', c),
            ]),
          ]),
        ),
        const SectionTitle('Examens blancs'),
        ListBox(children: [
          if (exams.isEmpty)
            Row2(
              title: 'Aucun examen blanc',
              subtitle: 'Passez le premier : ${AppConfig.examQuestions} questions en ${AppConfig.examMinutes} minutes.',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => runAction(context, 'exam'),
            ),
          for (final e in exams)
            Row2(
              title: shortDate(e.playedOn),
              subtitle: 'Seuil : ${(AppConfig.examPassRatio * e.total).ceil()}/${e.total}',
              trailing: Pill('${e.correct}/${e.total} · ${(e.passed ?? false) ? 'Réussi' : 'Non réussi'}',
                  tone: (e.passed ?? false) ? Tone.ok : Tone.ko),
            ),
        ]),
        const SectionTitle('Format examen et rapports'),
        ListBox(children: [
          if (scored.isEmpty)
            const Row2(title: 'Rien pour l’instant', subtitle: 'Vos notes aux cas d’examen et aux rapports apparaîtront ici.'),
          for (final e in scored)
            Row2(
              title: e.mode,
              subtitle: shortDate(e.playedOn),
              trailing: Pill('${frNumber(20 * e.correct / e.total)} / 20', tone: toneForPercent((100 * e.correct / e.total).round())),
            ),
        ]),
        SectionTitle('Badges', trailing: Pill('${d.badges.length}/${badgeDefs.length}')),
        _BadgeGrid(earned: d.badges),
      ]),
    );
  }

  Widget _legend(Color color, String label, SiffletColors c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
      ]);
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.law, required this.percent});
  final int law;
  final int? percent;
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final color = switch (toneForPercent(percent)) {
      Tone.ok => c.pitch,
      Tone.mid => c.card,
      Tone.ko => c.red,
      Tone.none => c.line,
    };
    return Semantics(
      label: 'Loi $law, ${lawName(law)} : ${percent == null ? 'pas encore travaillée' : '$percent pour cent'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          SizedBox(width: 28, child: Text('$law', style: TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w800, fontSize: 16, color: c.muted))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lawName(law), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: (percent ?? 0) / 100, minHeight: 7, backgroundColor: c.surface2, color: color),
              ),
            ]),
          ),
          SizedBox(
            width: 46,
            child: Text(percent == null ? '—' : '$percent %',
                textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.earned});
  final Set<String> earned;
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final tiles = [
      for (final b in badgeDefs)
        Opacity(
          opacity: earned.contains(b.id) ? 1 : .5,
          child: Panel(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: earned.contains(b.id) ? c.card : c.surface2,
                  shape: BoxShape.circle,
                  border: earned.contains(b.id) ? null : Border.all(color: c.line),
                ),
                child: Icon(earned.contains(b.id) ? Icons.star_rounded : Icons.lock_outline, size: 18, color: earned.contains(b.id) ? c.onCard : c.muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
                  Text(b.description, style: TextStyle(fontSize: 12, color: c.muted, height: 1.25)),
                ]),
              ),
            ]),
          ),
        ),
    ];
    return TileGrid(children: tiles);
  }
}

