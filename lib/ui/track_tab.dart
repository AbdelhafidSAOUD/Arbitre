import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../logic/dates.dart';
import '../logic/progress.dart';
import '../models/content.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'charts.dart';
import 'common.dart';
import 'home_tab.dart';

class TrackTab extends StatelessWidget {
  const TrackTab({super.key});

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
    final recentMatches = d.matches.take(5).toList();
    final avg = [
      for (final (k, _) in evalCriteria)
        recentMatches.isEmpty ? 0.0 : recentMatches.map((m) => m.eval(k)).reduce((a, b) => a + b) / recentMatches.length,
    ];
    final weakest = recentMatches.isEmpty ? null : evalCriteria[avg.indexOf(avg.reduce((a, b) => a < b ? a : b))].$2;
    final notes = [
      for (final m in d.matches.reversed)
        if (m.observerNote != null) (m.playedOn, m.observerNote!),
    ];

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

    return PageList(children: [
      const Headline(eyebrow: 'Suivi', title: 'Ma progression'),
      const SizedBox(height: 16),
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
      const SectionTitle('Mes matchs'),
      if (recentMatches.isNotEmpty) ...[
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Auto-évaluation', style: Theme.of(context).textTheme.titleLarge),
            Text('Moyenne des ${recentMatches.length} derniers matchs, sur 5', style: TextStyle(fontSize: 13, color: c.muted)),
            const SizedBox(height: 6),
            RadarChart(labels: [for (final (_, label) in evalCriteria) label], values: avg),
            Text.rich(TextSpan(children: [
              const TextSpan(text: 'Axe à travailler en priorité : '),
              TextSpan(text: weakest, style: const TextStyle(fontWeight: FontWeight.w700)),
              const TextSpan(text: '.'),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (notes.length >= 2) ...[
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Notes d’observation', style: Theme.of(context).textTheme.titleLarge)),
              Text('${frNumber(notes.last.$2)}/20', style: TextStyle(fontFamily: kDisplay, fontSize: 22, fontWeight: FontWeight.w800, color: c.ink)),
            ]),
            const SizedBox(height: 8),
            NotesSparkline(points: notes),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: Text('Carnet de matchs', style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MatchFormScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter un match'),
        ),
      ]),
      const SizedBox(height: 6),
      ListBox(children: [
        if (d.matches.isEmpty)
          const Row2(
            title: 'Aucun match enregistré',
            subtitle: 'Ajoutez votre dernier match pour suivre vos notes et votre auto-évaluation.',
          ),
        for (final m in d.matches)
          Row2(
            title: m.competition,
            subtitle: '${shortDate(m.playedOn)} · ${m.role}${(m.improvement?.isNotEmpty ?? false) ? '\n${m.improvement}' : ''}',
            trailing: m.observerNote == null
                ? const Icon(Icons.chevron_right)
                : Text('${frNumber(m.observerNote!)}/20',
                    style: TextStyle(fontFamily: kDisplay, fontSize: 20, fontWeight: FontWeight.w800, color: c.ink)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatchFormScreen(existing: m))),
          ),
      ]),
      SectionTitle('Badges', trailing: Pill('${d.badges.length}/${badgeDefs.length}')),
      _BadgeGrid(earned: d.badges),
    ]);
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

/// Ajout ou modification d'un match du carnet.
class MatchFormScreen extends StatefulWidget {
  const MatchFormScreen({super.key, this.existing});
  final MatchEntry? existing;
  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _form = GlobalKey<FormState>();
  late DateTime date;
  late final TextEditingController comp, note, improve;
  late String role;
  late Map<String, int> evals;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    date = (m == null ? null : parseDay(m.playedOn)) ?? DateTime.now();
    comp = TextEditingController(text: m?.competition ?? '');
    note = TextEditingController(text: m?.observerNote == null ? '' : frNumber(m!.observerNote!));
    improve = TextEditingController(text: m?.improvement ?? '');
    role = m?.role ?? matchRoles.first;
    evals = {for (final (k, _) in evalCriteria) k: m?.eval(k) ?? 3};
  }

  @override
  void dispose() {
    comp.dispose();
    note.dispose();
    improve.dispose();
    super.dispose();
  }

  double? _parseNote(String v) => v.trim().isEmpty ? null : double.tryParse(v.trim().replaceAll(',', '.'));

  void _save() {
    if (!_form.currentState!.validate()) return;
    final s = AppScope.read(context);
    final fresh = s.saveMatch(MatchEntry(
      id: widget.existing?.id ?? s.newId(),
      playedOn: isoDay(date),
      competition: comp.text.trim(),
      role: role,
      observerNote: _parseNote(note.text),
      improvement: improve.text.trim(),
      evals: Map.of(evals),
    ));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(content: Text(fresh.isEmpty ? 'Match enregistré' : 'Match enregistré · Badge : ${fresh.first.name}')));
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce match ?'),
        content: const Text('Il sera retiré de votre carnet et de vos statistiques.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    AppScope.read(context).deleteMatch(widget.existing!.id);
    Navigator.of(context).pop();
    messenger.showSnackBar(const SnackBar(content: Text('Match supprimé')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Nouveau match' : 'Modifier le match'),
        actions: [
          if (widget.existing != null) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _form,
        child: PageList(children: [
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
            decoration: const InputDecoration(labelText: 'Compétition', hintText: 'ex. U19 Régional 1'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez la compétition.' : null,
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'Rôle'),
            items: [for (final r in matchRoles) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => role = v ?? role),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 20),
          const Eyebrow('Auto-évaluation, de 1 à 5'),
          const SizedBox(height: 8),
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
          const SizedBox(height: 6),
          TextFormField(
            controller: improve,
            maxLength: 500,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Points à améliorer', hintText: 'Placement, gestion des bancs, signalétique…'),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _save, child: const Text('Enregistrer le match')),
        ]),
      ),
    );
  }
}
