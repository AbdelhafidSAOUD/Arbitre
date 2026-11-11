import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../models/content.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'common.dart';
import 'learn_tab.dart';
import 'quiz_screen.dart';

/// Lance une séance ou ouvre une fiche selon le type de tâche.
void runAction(BuildContext context, String kind, {int? law}) {
  final state = AppScope.read(context);
  if (kind == 'lesson') {
    openLesson(context, law!);
    return;
  }
  startQuiz(context, state.configFor(kind, law: law));
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final p = s.profile;
    final lv = s.level;
    final tasks = s.dailyProgram();
    final done = tasks.where((t) => t.done).length;
    final weak = s.weakLaws(3);
    final recent = s.data.sessions.reversed.take(4).toList();

    return PageList(children: [
      // Tableau de score
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: c.navy, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(p.firstName?.isNotEmpty ?? false) ? 'Bonjour ${p.firstName} · ' : ''}Niveau actuel',
                    style: TextStyle(fontSize: 13, color: c.onNavy.withValues(alpha: .78))),
                Text('ARBITRE ${lv.name.toUpperCase()}',
                    style: TextStyle(fontFamily: kDisplay, fontSize: 28, fontWeight: FontWeight.w800, color: c.onNavy, height: 1.05)),
                Text('${p.xp} XP${lv.next != null ? ' · ${lv.next! - p.xp} XP avant ${lv.nextName}' : ''}',
                    style: TextStyle(fontSize: 13, color: c.onNavy.withValues(alpha: .78))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${p.streak}', style: TextStyle(fontFamily: kDisplay, fontSize: 40, fontWeight: FontWeight.w800, color: c.card, height: 1)),
              Text('JOURS\nDE SUITE',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, letterSpacing: 1, color: c.onNavy.withValues(alpha: .78), height: 1.2)),
            ]),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: lv.progress(p.xp),
              minHeight: 8,
              backgroundColor: c.onNavy.withValues(alpha: .18),
              color: c.card,
            ),
          ),
        ]),
      ),
      if (s.syncError != null) ...[
        const SizedBox(height: 10),
        Text(s.syncError!, style: TextStyle(fontSize: 13, color: c.muted)),
      ],
      SectionTitle('Programme du jour', trailing: Pill('$done/${tasks.length}', tone: done == tasks.length ? Tone.ok : Tone.none)),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Adapté à votre objectif : ${profileGoals[p.goal]!.toLowerCase()}.', style: TextStyle(fontSize: 13, color: c.muted)),
      ),
      ListBox(children: [
        for (final t in tasks)
          Row2(
            leading: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.done ? c.pitch : null,
                border: Border.all(color: t.done ? c.pitch : c.line, width: 2),
              ),
              child: t.done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            title: t.label,
            subtitle: t.subtitle,
            strike: t.done,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => runAction(context, t.kind, law: t.law),
          ),
      ]),
      const SizedBox(height: 16),
      TileGrid(children: [
        ActionTile(icon: Icons.bolt, title: 'Quiz rapide', subtitle: '10 questions dont 2 hors-jeu animés', onTap: () => runAction(context, 'quick')),
        ActionTile(icon: Icons.timer_outlined, title: 'Mode match', subtitle: '${AppConfig.secondsPerQuestion} s pour décider', onTap: () => runAction(context, 'match')),
        ActionTile(icon: Icons.flag_outlined, title: 'Simulateur hors-jeu', subtitle: 'Situations générées à l’infini', onTap: () => runAction(context, 'offside')),
        ActionTile(
            icon: Icons.assignment_outlined,
            title: 'Examen blanc',
            subtitle: '${AppConfig.examQuestions} questions, ${AppConfig.examMinutes} min',
            onTap: () => runAction(context, 'exam')),
      ]),
      SectionTitle('À retravailler', trailing: const Eyebrow('Maîtrise')),
      ListBox(children: [
        for (final l in weak)
          Row2(
            leading: LawNumber(l),
            title: lawName(l),
            subtitle: 'Ouvrir la fiche et s’entraîner',
            trailing: Pill(s.lawPercent(l) == null ? 'Jamais vue' : '${s.lawPercent(l)} %', tone: toneForPercent(s.lawPercent(l))),
            onTap: () => openLesson(context, l),
          ),
      ]),
      const SectionTitle('Dernières séances'),
      ListBox(children: [
        if (recent.isEmpty)
          Row2(title: 'Aucune séance pour l’instant', subtitle: 'Lancez un quiz rapide pour commencer.', onTap: () => runAction(context, 'quick')),
        for (final r in recent)
          Row2(
            title: r.mode,
            subtitle: shortDate(r.playedOn),
            trailing: Pill('${r.correct}/${r.total}', tone: toneForPercent((100 * r.correct / r.total).round())),
          ),
      ]),
    ]);
  }
}
