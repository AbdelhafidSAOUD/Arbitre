import 'dart:math';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/dates.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'common.dart';
import 'home_tab.dart';
import 'physical_tab.dart';
import 'report_screen.dart';

/// Points à travailler → exercice conseillé dans l'application.
(String, void Function(BuildContext))? exerciseFor(String workPoint) => switch (workPoint) {
      'Lecture du hors-jeu' => ('Simulateur hors-jeu', (c) => runAction(c, 'offside')),
      'Placement sur coups de pied arrêtés' => ('Questions loi 13', (c) => runAction(c, 'law', law: 13)),
      'Timing des cartons' || 'Gestion des conflits' => ('Questions loi 12', (c) => runAction(c, 'law', law: 12)),
      'Gestion des bancs' => ('Questions loi 5', (c) => runAction(c, 'law', law: 5)),
      'Sprint de repli' => (
          'Physique',
          (c) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: PhysicalTab()))))
        ),
      'Concentration en fin de match' => ('Mode match', (c) => runAction(c, 'match')),
      'Communication avec l’équipe arbitrale' || 'Gestuelle et signaux' => ('Questions loi 6', (c) => runAction(c, 'law', law: 6)),
      _ => null,
    };

class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final d = s.data;
    final planned = d.plannedMatches;
    final played = d.playedMatches;
    final withSat = [for (final m in played.reversed) if (m.satisfaction != null) m];
    final recent = withSat.length > 8 ? withSat.sublist(withSat.length - 8) : withSat;
    final freq = <String, int>{};
    for (final m in played.take(10)) {
      for (final w in m.workPoints) {
        freq[w] = (freq[w] ?? 0) + 1;
      }
    }
    final top = freq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return PageList(children: [
      Row(children: [
        const Expanded(child: Headline(eyebrow: 'Matchs', title: 'Mes matchs')),
        FilledButton.icon(
          style: compactButton,
          onPressed: () => openMatchForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter'),
        ),
      ]),
      const SectionTitle('À venir'),
      if (planned.isEmpty)
        Panel(
          child: Text('Aucun match prévu. Ajoutez votre prochaine désignation et fixez-vous un objectif.',
              style: TextStyle(fontSize: 14, color: c.muted)),
        ),
      for (final m in planned) ...[
        _PlannedCard(m: m),
        const SizedBox(height: 10),
      ],
      if (recent.length >= 2) ...[
        const SectionTitle('Ma tendance'),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Satisfaction après match', style: Theme.of(context).textTheme.titleLarge),
            Text('${recent.length} derniers matchs débriefés, de 1 à 5', style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 8),
            SatisfactionChart(points: [for (final m in recent) (m.playedOn, m.satisfaction!)]),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Eyebrow('Ce qui revient le plus'),
              const SizedBox(height: 6),
              for (final e in top.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' · ${e.value} match${e.value > 1 ? 's' : ''}', style: TextStyle(color: c.muted)),
                      ])),
                    ),
                    if (exerciseFor(e.key) case final ex?)
                      ActionChip(label: Text('${ex.$1} ›'), onPressed: () => ex.$2(context)),
                  ]),
                ),
            ],
          ]),
        ),
      ],
      const SectionTitle('Joués'),
      ListBox(children: [
        if (played.isEmpty)
          const Row2(
            title: 'Aucun match joué enregistré',
            subtitle: 'Après chaque match, faites votre débriefing : ressenti, notes, points à travailler.',
          ),
        for (final m in played)
          Row2(
            title: '${shortDate(m.playedOn)} · ${m.competition}',
            subtitle: [
              m.role,
              if ((m.teams ?? '').isNotEmpty) m.teams!,
              if ((m.feeling ?? m.improvement ?? '').isNotEmpty) '« ${m.feeling ?? m.improvement} »',
            ].join('\n'),
            trailing: m.satisfaction != null
                ? Pill(satisfactionLabels[m.satisfaction!], tone: m.satisfaction! >= 4 ? Tone.ok : m.satisfaction! >= 3 ? Tone.mid : Tone.ko)
                : m.observerNote != null
                    ? Text('${frNumber(m.observerNote!)}/20',
                        style: TextStyle(fontFamily: kDisplay, fontSize: 20, fontWeight: FontWeight.w800, color: c.ink))
                    : const Icon(Icons.chevron_right),
            onTap: () => openMatchForm(context, existing: m),
          ),
      ]),
    ]);
  }
}

void openMatchForm(BuildContext context, {MatchEntry? existing, bool debrief = false}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchFormScreen(existing: existing, debrief: debrief)));

class _PlannedCard extends StatelessWidget {
  const _PlannedCard({required this.m});
  final MatchEntry m;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${_weekday(m.playedOn)} ${shortDate(m.playedOn)}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: c.ink)),
          ),
          Pill(m.role),
        ]),
        const SizedBox(height: 4),
        Text([m.competition, if ((m.teams ?? '').isNotEmpty) m.teams!].join(' · '), style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        if ((m.goal ?? '').isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: c.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: c.pitch, width: 4)),
            ),
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Objectif : ', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: m.goal),
            ])),
          )
        else
          Text('Pas encore d’objectif pour ce match.', style: TextStyle(fontSize: 13, color: c.muted)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => openMatchForm(context, existing: m, debrief: true),
              child: const Text('Match joué : débriefer'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(style: compactButton, onPressed: () => openMatchForm(context, existing: m), child: const Text('Modifier')),
        ]),
      ]),
    );
  }
}

String _weekday(String iso) {
  final d = parseDay(iso);
  if (d == null) return '';
  return const ['Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.', 'Dim.'][d.weekday - 1];
}

/// Courbe de satisfaction (1 à 5) des derniers matchs.
class SatisfactionChart extends StatelessWidget {
  const SatisfactionChart({super.key, required this.points});
  final List<(String, int)> points;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Satisfaction des derniers matchs : ${points.map((p) => p.$2).join(', ')} sur 5',
        excludeSemantics: true,
        child: AspectRatio(aspectRatio: 320 / 120, child: CustomPaint(painter: _SatPainter(points, context.sc))),
      );
}

class _SatPainter extends CustomPainter {
  _SatPainter(this.points, this.c);
  final List<(String, int)> points;
  final SiffletColors c;

  @override
  void paint(Canvas canvas, Size size) {
    const pl = 20.0, pr = 14.0, pt = 10.0, pb = 22.0;
    double x(int i) => points.length == 1 ? pl : pl + i * (size.width - pl - pr) / (points.length - 1);
    double y(num v) => pt + (5 - v) * (size.height - pt - pb) / 4;
    final text = TextStyle(color: c.muted, fontSize: 10, fontFamily: kBody);
    for (final v in [1, 3, 5]) {
      canvas.drawLine(Offset(pl, y(v)), Offset(size.width - pr, y(v)), Paint()..color = c.line);
      final tp = TextPainter(text: TextSpan(text: '$v', style: text), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pl - 6 - tp.width, y(v) - tp.height / 2));
    }
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      i == 0 ? path.moveTo(x(i), y(points[i].$2)) : path.lineTo(x(i), y(points[i].$2));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = c.pitch
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].$2)), i == points.length - 1 ? 5 : 3.5, Paint()..color = c.pitch);
      if (points.length <= 6 || i.isEven || i == points.length - 1) {
        final tp = TextPainter(text: TextSpan(text: shortDate(points[i].$1), style: text), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(min(max(0, x(i) - tp.width / 2), size.width - tp.width), size.height - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SatPainter old) => old.points != points;
}

/// Ajout d'un match prévu, modification, ou débriefing après le match.
class MatchFormScreen extends StatefulWidget {
  const MatchFormScreen({super.key, this.existing, this.debrief = false});
  final MatchEntry? existing;
  /// Vrai quand on passe un match prévu à « joué ».
  final bool debrief;
  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _form = GlobalKey<FormState>();
  late DateTime date;
  late final TextEditingController comp, teams, goal, feeling, nextGoal, note, extraWork;
  late String role;
  late Map<String, int> evals;
  late Set<String> work;
  late List<String> customWork;
  String? goalResult;
  int? satisfaction;
  int yellow = 0, red = 0;

  MatchEntry? get m => widget.existing;
  bool get isPlayed => widget.debrief || (m != null && !m!.planned) || (m == null && !_planning);
  bool _planning = true;

  @override
  void initState() {
    super.initState();
    date = (m == null ? null : parseDay(m!.playedOn)) ?? DateTime.now().add(const Duration(days: 3));
    comp = TextEditingController(text: m?.competition ?? '');
    teams = TextEditingController(text: m?.teams ?? '');
    goal = TextEditingController(text: m?.goal ?? '');
    feeling = TextEditingController(text: m?.feeling ?? m?.improvement ?? '');
    nextGoal = TextEditingController(text: m?.nextGoal ?? '');
    note = TextEditingController(text: m?.observerNote == null ? '' : frNumber(m!.observerNote!));
    extraWork = TextEditingController();
    role = m?.role ?? (AppScope.read(context).profile.isAssistant ? matchRoles[1] : matchRoles[0]);
    evals = {for (final (k, _) in evalCriteria) k: m?.eval(k) ?? 3};
    work = {...?m?.workPoints};
    customWork = [for (final w in work) if (!workPointChoices.contains(w)) w];
    goalResult = m?.goalResult;
    satisfaction = m?.satisfaction;
    yellow = m?.yellowCards ?? 0;
    red = m?.redCards ?? 0;
    if (widget.debrief && m != null && parseDay(m!.playedOn)!.isAfter(DateTime.now())) date = DateTime.now();
  }

  @override
  void dispose() {
    for (final t in [comp, teams, goal, feeling, nextGoal, note, extraWork]) {
      t.dispose();
    }
    super.dispose();
  }

  double? _parseNote(String v) => v.trim().isEmpty ? null : double.tryParse(v.trim().replaceAll(',', '.'));

  void _save() {
    if (!_form.currentState!.validate()) return;
    if (isPlayed && satisfaction == null) {
      showMessage(context, 'Indiquez au moins votre satisfaction globale.');
      return;
    }
    final s = AppScope.read(context);
    final entry = MatchEntry(
      id: m?.id ?? s.newId(),
      playedOn: isoDay(date),
      competition: comp.text.trim(),
      role: role,
      status: isPlayed ? 'joue' : 'prevu',
      teams: teams.text,
      goal: goal.text,
      goalResult: isPlayed ? goalResult : null,
      satisfaction: isPlayed ? satisfaction : null,
      feeling: isPlayed ? feeling.text : null,
      workPoints: isPlayed ? work.toList() : const [],
      nextGoal: isPlayed ? nextGoal.text : null,
      yellowCards: isPlayed ? yellow : 0,
      redCards: isPlayed ? red : 0,
      observerNote: _parseNote(note.text),
      improvement: m?.improvement,
      evals: Map.of(evals),
    );
    final fresh = s.saveMatch(entry);
    // L'objectif fixé pour la suite est reporté sur le prochain match prévu.
    final next = entry.nextGoal?.trim() ?? '';
    if (isPlayed && next.isNotEmpty) {
      final upcoming = s.data.plannedMatches.where((x) => (x.goal ?? '').isEmpty).toList();
      if (upcoming.isNotEmpty) s.saveMatch(upcoming.first.copyWith(goal: () => next));
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
        content: Text(fresh.isEmpty
            ? (isPlayed ? 'Débriefing enregistré' : 'Match ajouté à vos matchs à venir')
            : 'Enregistré · Badge : ${fresh.first.name}')));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce match ?'),
        content: const Text('Il sera retiré de vos matchs et de vos statistiques.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    AppScope.read(context).deleteMatch(m!.id);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Match supprimé')));
  }

  Widget _counter(String label, int value, int maxV, ValueChanged<int> set) {
    final c = context.sc;
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.ink))),
      IconButton(
        tooltip: 'Moins',
        onPressed: value > 0 ? () => setState(() => set(value - 1)) : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(
        width: 28,
        child: Text('$value',
            textAlign: TextAlign.center, style: TextStyle(fontFamily: kDisplay, fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
      ),
      IconButton(
        tooltip: 'Plus',
        onPressed: value < maxV ? () => setState(() => set(value + 1)) : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final title = widget.debrief
        ? 'Débriefing'
        : m == null
            ? 'Nouveau match'
            : 'Modifier le match';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (m != null) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _form,
        child: PageList(children: [
          if (m == null) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Match à venir'), icon: Icon(Icons.event)),
                ButtonSegment(value: false, label: Text('Match joué'), icon: Icon(Icons.sports)),
              ],
              selected: {_planning},
              onSelectionChanged: (v) => setState(() {
                _planning = v.first;
                if (!_planning && date.isAfter(DateTime.now())) date = DateTime.now();
              }),
            ),
            const SizedBox(height: 14),
          ],
          if (widget.debrief) ...[
            Text('${m!.competition}${(m!.teams ?? '').isNotEmpty ? ' · ${m!.teams}' : ''}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Prenez 3 minutes à chaud : c’est ce qui fait progresser d’un match à l’autre.',
                style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 14),
          ],
          OutlinedButton.icon(
            icon: const Icon(Icons.event),
            label: Text('Date : ${date.day}/${date.month}/${date.year}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => date = picked);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: comp,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Compétition', hintText: 'ex. Régional 2, U19 Régional 1'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez la compétition.' : null,
          ),
          TextFormField(
            controller: teams,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Équipes (facultatif)', hintText: 'Domicile – Visiteur'),
          ),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Ma fonction'),
            items: [for (final r in matchRoles) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => role = v ?? role),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: goal,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Mon objectif pour ce match', hintText: 'ex. Siffler fort et tôt sur la première faute'),
          ),
          if (isPlayed) ...[
            if (goal.text.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              const Eyebrow('Objectif atteint ?'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final (k, l) in const [('atteint', 'Atteint'), ('en_partie', 'En partie'), ('non_atteint', 'Pas atteint')])
                  ChoiceChip(label: Text(l), selected: goalResult == k, onSelected: (on) => setState(() => goalResult = on ? k : null)),
              ]),
            ],
            const SectionTitle('Satisfaction globale'),
            Row(children: [
              for (var v = 1; v <= 5; v++) ...[
                Expanded(
                  child: _FaceButton(
                    value: v,
                    selected: satisfaction == v,
                    onTap: () => setState(() => satisfaction = v),
                  ),
                ),
                if (v < 5) const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: feeling,
              maxLength: 1000,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mon ressenti',
                hintText: 'Comment s’est passé mon match ? Ce qui a marché, ce qui a moins marché, les moments clés…',
                alignLabelWithHint: true,
              ),
            ),
            const SectionTitle('Mes notes, de 1 à 5'),
            for (final (k, label) in evalCriteria)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: c.muted))),
                  Text('${evals[k]}', style: TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w800, fontSize: 18, color: c.ink)),
                ]),
                Slider(
                  value: evals[k]!.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '${evals[k]}',
                  semanticFormatterCallback: (v) => '$label : ${v.round()} sur 5',
                  onChanged: (v) => setState(() => evals[k] = v.round()),
                ),
              ]),
            const SectionTitle('Cartons donnés'),
            _counter('Avertissements', yellow, 30, (v) => yellow = v),
            _counter('Exclusions', red, 11, (v) => red = v),
            if (red > 0)
              Panel(
                color: c.surface2,
                child: Row(children: [
                  const Expanded(
                    child: Text('Vous avez exclu un joueur : le rapport est à envoyer, en général sous 48 h. '
                        'Entraînez-vous avec l’atelier, sans y mettre de vrais noms.'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: compactButton,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportScreen())),
                    child: const Text('Atelier'),
                  ),
                ]),
              ),
            const SectionTitle('Points à travailler'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final w in [...workPointChoices, ...customWork])
                FilterChip(
                  label: Text(w),
                  selected: work.contains(w),
                  onSelected: (on) => setState(() => on ? work.add(w) : work.remove(w)),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: extraWork,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Autre point à travailler'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: compactButton,
                onPressed: () {
                  final v = extraWork.text.trim();
                  if (v.isEmpty) return;
                  setState(() {
                    if (!customWork.contains(v) && !workPointChoices.contains(v)) customWork.add(v);
                    work.add(v);
                    extraWork.clear();
                  });
                },
                child: const Text('Ajouter'),
              ),
            ]),
            TextFormField(
              controller: nextGoal,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mon objectif pour le prochain match',
                hintText: 'Il s’affichera sur votre prochain match prévu',
              ),
            ),
            TextFormField(
              controller: note,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: const InputDecoration(labelText: 'Note de l’observateur (sur 20, facultatif)', hintText: 'ex. 14,5'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = _parseNote(v);
                if (n == null || n < 0 || n > 20) return 'La note doit être un nombre entre 0 et 20.';
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _save,
            child: Text(isPlayed ? 'Enregistrer le débriefing' : 'Enregistrer le match'),
          ),
          if (isPlayed) ...[
            const SizedBox(height: 8),
            Text('Vos débriefings restent privés : ni observateur ni formateur ne les voit.',
                style: TextStyle(fontSize: 13, color: c.muted)),
          ],
        ]),
      ),
    );
  }
}

class _FaceButton extends StatelessWidget {
  const _FaceButton({required this.value, required this.selected, required this.onTap});
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Satisfaction $value sur 5 : ${satisfactionLabels[value]}',
      excludeSemantics: true,
      child: Material(
        color: selected ? c.pitchSoft : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? c.pitch : c.line, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              Text('$value', style: TextStyle(fontFamily: kDisplay, fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
              Text(satisfactionLabels[value].replaceFirst('Très ', 'Très\n'),
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, height: 1.15, color: c.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
