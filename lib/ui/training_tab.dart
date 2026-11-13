import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../models/content.dart';
import 'common.dart';
import 'exam_cases_screen.dart';
import 'report_screen.dart';
import 'home_tab.dart';

class TrainingTab extends StatelessWidget {
  const TrainingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final due = s.dueQuestionIds().length;
    return PageList(children: [
      Headline(
        eyebrow: 'S’entraîner',
        title: 'Choisir une séance',
        subtitle: 'Les questions s’adaptent à votre profil : '
            '${s.profile.categoryLabel}, ${s.profile.isAssistant ? 'arbitre assistant' : 'arbitre central'}.',
      ),
      const SizedBox(height: 16),
      ActionTile(
        primary: true,
        icon: Icons.autorenew,
        title: 'Révisions espacées',
        subtitle: due > 0
            ? '$due question${due > 1 ? 's' : ''} à revoir aujourd’hui'
            : 'Rien à revoir aujourd’hui. Vos erreurs reviendront ici au bon moment.',
        onTap: due > 0 ? () => runAction(context, 'review') : null,
      ),
      const SizedBox(height: 10),
      TileGrid(children: [
        ActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Format examen',
          subtitle: '${s.content.examCases.length} cas · cocher toutes les décisions',
          onTap: () => openExamCases(context),
        ),
        ActionTile(
          icon: Icons.edit_note,
          title: 'Rapport disciplinaire',
          subtitle: 'Rédiger, être corrigé, comparer au modèle',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen())),
        ),
        ActionTile(icon: Icons.bolt, title: 'Quiz rapide', subtitle: '10 questions, toutes lois', onTap: () => runAction(context, 'quick')),
        ActionTile(
            icon: Icons.timer_outlined,
            title: 'Mode match',
            subtitle: 'Chrono de ${AppConfig.secondsPerQuestion} s, +5 XP par bonne réponse',
            onTap: () => runAction(context, 'match')),
        ActionTile(icon: Icons.flag_outlined, title: 'Simulateur hors-jeu', subtitle: 'Jugez la position au moment de la passe', onTap: () => runAction(context, 'offside')),
        ActionTile(icon: Icons.assignment_outlined, title: 'Examen blanc', subtitle: 'Correction à la fin uniquement', onTap: () => runAction(context, 'exam')),
        ActionTile(icon: Icons.track_changes, title: 'Révision ciblée', subtitle: 'Vos 3 lois les plus fragiles', onTap: () => runAction(context, 'weak')),
        ActionTile(icon: Icons.co_present_outlined, title: 'Séance en salle', subtitle: 'Formateurs : projeter, faire voter, révéler', onTap: () => runAction(context, 'classroom')),
      ]),
      const SectionTitle('Par loi'),
      ListBox(children: [
        for (var l = 1; l <= 17; l++)
          Builder(builder: (context) {
            final n = s.content.countForLaw(l);
            final p = s.lawPercent(l);
            return Row2(
              leading: LawNumber(l),
              title: lawName(l),
              subtitle: '$n question${n > 1 ? 's' : ''}${l == 11 ? ' + simulateur' : ''}',
              trailing: Pill(p == null ? '—' : '$p %', tone: toneForPercent(p)),
              onTap: n == 0 ? null : () => runAction(context, 'law', law: l),
            );
          }),
      ]),
    ]);
  }
}
