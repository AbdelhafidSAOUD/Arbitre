import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/dates.dart';
import '../logic/physical.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'common.dart';

class PhysicalTab extends StatelessWidget {
  const PhysicalTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final p = s.profile;
    final mine = testsFor(p);
    final asst = p.isAssistant;
    final onNavyMuted = c.onNavy.withValues(alpha: .75);

    return PageList(children: [
      const Headline(eyebrow: 'Physique', title: 'Préparer mes tests'),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.navy, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('MES TESTS · SAISON 2025/26',
              style: TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: onNavyMuted)),
          const SizedBox(height: 4),
          Text('${asst ? 'Arbitre assistant' : 'Arbitre central'}${(p.levelDetail ?? '').isNotEmpty ? ' · ${p.levelDetail}' : ''}',
              style: TextStyle(fontFamily: kDisplay, fontSize: 24, fontWeight: FontWeight.w800, color: c.onNavy)),
          const SizedBox(height: 6),
          for (final (t, th) in mine)
            InkWell(
              onTap: () => _openTest(context, t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: TextStyle(fontWeight: FontWeight.w700, color: c.onNavy)),
                      Text(th.who, style: TextStyle(fontSize: 12.5, color: onNavyMuted)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(99)),
                    child: Text(th.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: c.onCard)),
                  ),
                ]),
              ),
            ),
          if ((p.levelDetail ?? '').isEmpty)
            Text('Indiquez votre niveau précis (R2, R1…) dans votre profil pour voir vos temps exacts.',
                style: TextStyle(fontSize: 12.5, color: onNavyMuted)),
          const SizedBox(height: 4),
          Text('Réussir le test conditionne les désignations. Échec après rattrapage : catégorie inférieure, pas de promotion.',
              style: TextStyle(fontSize: 12.5, color: onNavyMuted)),
        ]),
      ),
      const SectionTitle('S’entraîner'),
      TileGrid(children: [
        ActionTile(
          primary: true,
          icon: Icons.timer_outlined,
          title: 'Séance S.D.S. guidée',
          subtitle: 'Le chrono du test, à vos distances',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SdsSessionScreen())),
        ),
        for (final t in physicalTests.where((t) => t.id != 'sds'))
          ActionTile(icon: _icon(t.id), title: t.name, subtitle: t.forWho, onTap: () => _openTest(context, t)),
        ActionTile(icon: Icons.info_outline, title: 'S.D.S. : le test', subtitle: 'Procédure et distances', onTap: () => _openTest(context, testById('sds'))),
      ]),
      const SectionTitle('Semaine type'),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (day, what) in [
            ('Lundi', 'Récupération active : 30 min de footing léger'),
            ('Mardi', 'Vitesse : 6 × ${asst ? '30' : '40'} m, récupération complète${asst ? ', puis 6 C.O.D.A.' : ''}'),
            ('Jeudi', asst ? 'A.R.I.E.T. ou intermittent course 20 m / pas chassés 12,5 m' : 'S.D.S. guidée, 2 blocs'),
            ('Week-end', 'Match'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 82, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text(what)),
              ]),
            ),
          Text('Proposition générale, à adapter avec votre préparateur physique.', style: TextStyle(fontSize: 12.5, color: c.muted)),
        ]),
      ),
      SectionTitle('Mon journal',
          trailing: TextButton.icon(onPressed: () => showResultDialog(context), icon: const Icon(Icons.add), label: const Text('Saisir'))),
      ListBox(children: [
        if (s.data.physical.isEmpty)
          Row2(
            title: 'Aucun résultat',
            subtitle: 'Saisissez vos temps d’entraînement pour suivre votre progression vers les barèmes.',
            onTap: () => showResultDialog(context),
          ),
        for (final r in s.data.physical)
          Row2(
            title: '${testById(r.test).name} · ${r.value}${testById(r.test).unit == TestUnit.seconds ? ' s' : ''}',
            subtitle: shortDate(r.doneOn),
            trailing: r.passed == null ? null : Pill(r.passed! ? 'Validé' : 'À travailler', tone: r.passed! ? Tone.ok : Tone.ko),
            onTap: () => showResultDialog(context, existing: r),
          ),
      ]),
      const SizedBox(height: 10),
      Text('Barèmes : tableau des tests physiques de la CRA, saison 2025/26. Ils varient selon les ligues.',
          style: TextStyle(fontSize: 12.5, color: c.muted)),
    ]);
  }

  IconData _icon(String id) => switch (id) {
        'coda' => Icons.swap_horiz,
        'ariet' => Icons.monitor_heart_outlined,
        _ => Icons.speed,
      };

  void _openTest(BuildContext context, PhysicalTest t) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TestDetailScreen(test: t)));
}

/// Saisie (ou modification) d'un résultat de test.
Future<void> showResultDialog(BuildContext context, {PhysicalResult? existing, String? testId}) async {
  final s = AppScope.read(context);
  final mine = {for (final (t, th) in testsFor(s.profile)) t.id: th};
  final r = await showDialog<_ResultInput>(
    context: context,
    builder: (_) => _ResultDialog(existing: existing, initialTest: existing?.test ?? testId ?? mine.keys.first, mine: mine),
  );
  if (r == null) return;
  if (r.delete) {
    if (existing != null) s.deletePhysical(existing.id);
    return;
  }
  if (r.value.isEmpty) return;
  final th = mine[r.test];
  s.savePhysical(PhysicalResult(
    id: existing?.id ?? s.newId(),
    test: r.test,
    value: r.value,
    doneOn: isoDay(r.date),
    passed: th == null ? null : passes(th, r.value),
  ));
}

class _ResultInput {
  const _ResultInput(this.test, this.value, this.date, {this.delete = false});
  final String test, value;
  final DateTime date;
  final bool delete;
}

class _ResultDialog extends StatefulWidget {
  const _ResultDialog({required this.existing, required this.initialTest, required this.mine});
  final PhysicalResult? existing;
  final String initialTest;
  final Map<String, TestThreshold> mine;
  @override
  State<_ResultDialog> createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog> {
  late String test = widget.initialTest;
  late final _value = TextEditingController(text: widget.existing?.value ?? '');
  late DateTime date = parseDay(widget.existing?.doneOn ?? '') ?? DateTime.now();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = testById(test);
    final th = widget.mine[test];
    return AlertDialog(
      title: Text(widget.existing == null ? 'Saisir un résultat' : 'Modifier le résultat'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          initialValue: test,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Test'),
          items: [for (final x in physicalTests) DropdownMenuItem(value: x.id, child: Text(x.name))],
          onChanged: (v) => setState(() => test = v ?? test),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _value,
          autofocus: widget.existing == null,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,"\- ]'))],
          decoration: InputDecoration(
            labelText: t.unit == TestUnit.seconds ? 'Temps (secondes)' : 'Palier atteint',
            hintText: t.unit == TestUnit.seconds ? 'ex. 4,88' : 'ex. 15-3',
            helperText: th == null ? null : 'Exigé pour vous : ${th.label}',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.event),
          label: Text('Le ${date.day}/${date.month}/${date.year}'),
          onPressed: () async {
            final picked = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (picked != null) setState(() => date = picked);
          },
        ),
      ]),
      actions: [
        if (widget.existing != null)
          TextButton(onPressed: () => Navigator.pop(context, _ResultInput(test, '', date, delete: true)), child: const Text('Supprimer')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          style: compactButton,
          onPressed: () => Navigator.pop(context, _ResultInput(test, _value.text.trim(), date)),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class TestDetailScreen extends StatelessWidget {
  const TestDetailScreen({super.key, required this.test});
  final PhysicalTest test;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Scaffold(
      appBar: AppBar(title: Text(test.name)),
      body: PageList(children: [
        Eyebrow(test.forWho),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AspectRatio(aspectRatio: 3, child: CustomPaint(painter: _SchemaPainter(test.id, c))),
            const SizedBox(height: 10),
            Text(test.procedure),
          ]),
        ),
        const SectionTitle('Temps et paliers à réaliser'),
        ListBox(children: [
          for (final th in test.thresholds) Row2(title: th.who, trailing: Pill(th.label, tone: Tone.mid)),
        ]),
        const SectionTitle('Pour s’entraîner'),
        Panel(child: Text(test.training)),
        const SizedBox(height: 16),
        if (test.id == 'sds')
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SdsSessionScreen())),
            child: const Text('Lancer la séance guidée'),
          )
        else
          FilledButton(onPressed: () => showResultDialog(context, testId: test.id), child: const Text('Saisir mon résultat')),
      ]),
    );
  }
}

/// Schéma simple du test : plots et trajets.
class _SchemaPainter extends CustomPainter {
  _SchemaPainter(this.id, this.c);
  final String id;
  final SiffletColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final text = TextStyle(color: c.muted, fontSize: 11, fontFamily: kBody);
    final ink = TextStyle(color: c.ink, fontSize: 11.5, fontFamily: kBody, fontWeight: FontWeight.w600);
    void cone(double x, String label) {
      final y = h * .5;
      final path = Path()
        ..moveTo(x, y - 8)
        ..lineTo(x - 7, y + 6)
        ..lineTo(x + 7, y + 6)
        ..close();
      canvas.drawPath(path, Paint()..color = c.card);
      final tp = TextPainter(text: TextSpan(text: label, style: text), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 9));
    }

    void route(double x1, double x2, double y, String label, {bool dashed = false, Color? color}) {
      final p = Paint()
        ..color = color ?? c.pitch
        ..strokeWidth = 2.5;
      if (dashed) {
        final dir = x2 > x1 ? 1 : -1;
        for (var x = x1; dir > 0 ? x < x2 : x > x2; x += 9 * dir) {
          canvas.drawLine(Offset(x, y), Offset(dir > 0 ? (x + 5).clamp(x1, x2) : (x - 5).clamp(x2, x1), y), p);
        }
      } else {
        canvas.drawLine(Offset(x1, y), Offset(x2, y), p);
      }
      final tp = TextPainter(text: TextSpan(text: label, style: ink), textDirection: TextDirection.ltr)..layout(maxWidth: w);
      tp.paint(canvas, Offset(((x1 + x2) / 2 - tp.width / 2).clamp(0, w - tp.width), y < h / 2 ? y - tp.height - 3 : y + 3));
    }

    switch (id) {
      case 'coda':
        cone(w * .08, 'A');
        cone(w * .22, 'B');
        cone(w * .9, 'C');
        route(w * .1, w * .88, h * .2, 'Course avant 10 m : A → C, puis C → A');
        route(w * .88, w * .24, h * .8, 'Pas chassés 8 m : C → B, puis B → C', dashed: true, color: c.attacker);
      case 'ariet':
        cone(w * .05, 'A');
        cone(w * .14, 'B');
        cone(w * .55, 'C');
        cone(w * .93, 'D');
        route(w * .16, w * .91, h * .2, 'Course 20 m : B → D, aller-retour');
        route(w * .16, w * .53, h * .8, 'Pas chassés 12,5 m', dashed: true, color: c.attacker);
      case 'sds':
        cone(w * .06, 'A');
        cone(w * .45, 'P');
        cone(w * .9, 'D');
        route(w * .08, w * .88, h * .2, 'Simple : A → D en 12 s');
        route(w * .88, w * .47, h * .8, 'Double : D → P → D en 16 s', dashed: true, color: c.attacker);
      default:
        cone(w * .06, 'Élan');
        cone(w * .16, '0 m');
        cone(w * .92, id == 'sprint40' ? '40 m' : '30 m');
        route(w * .18, w * .9, h * .2, 'Sprint, départ 1,5 m avant la cellule');
    }
  }

  @override
  bool shouldRepaint(covariant _SchemaPainter old) => old.id != id;
}

/// Séance S.D.S. guidée : enchaîne les courses et récupérations du test.
class SdsSessionScreen extends StatefulWidget {
  const SdsSessionScreen({super.key});
  @override
  State<SdsSessionScreen> createState() => _SdsSessionScreenState();
}

class _SdsSessionScreenState extends State<SdsSessionScreen> {
  late List<SdsStep> plan;
  late TestThreshold th;
  int i = 0;
  double left = 0;
  bool running = false;
  Timer? _timer;
  DateTime? _last;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    final sds = testById('sds');
    final mine = testsFor(p).where((x) => x.$1.id == 'sds');
    th = mine.isNotEmpty ? mine.first.$2 : sds.thresholds[1];
    plan = sdsPlan(th.distance!);
    left = plan.first.seconds.toDouble();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (running) {
      _timer?.cancel();
      setState(() => running = false);
      return;
    }
    _last = DateTime.now();
    HapticFeedback.mediumImpact();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final now = DateTime.now();
      final dt = now.difference(_last!).inMilliseconds / 1000;
      _last = now;
      setState(() {
        left -= dt;
        if (left <= 0) _next();
      });
    });
    setState(() => running = true);
  }

  void _next() {
    i++;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    if (i >= plan.length) {
      _timer?.cancel();
      running = false;
      return;
    }
    left = plan[i].seconds.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final done = i >= plan.length;
    final step = done ? null : plan[i];
    final next = i + 1 < plan.length ? plan[i + 1] : null;
    return Scaffold(
      appBar: AppBar(title: const Text('S.D.S. guidée')),
      body: PageList(children: [
        if (done) ...[
          const Headline(eyebrow: 'Bravo', title: 'Séance terminée'),
          const SizedBox(height: 12),
          const Text('3 blocs de 5 répétitions : c’est le volume complet du test.'),
        ] else ...[
          Row(children: [
            Expanded(child: Eyebrow('Distances : ${th.label} (${th.who})')),
            Pill('Bloc ${step!.block}/3 · Rép. ${step.rep}/5'),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
            decoration: BoxDecoration(color: step.run ? c.card : c.pitchSoft, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Text(step.run ? 'COUREZ' : 'RÉCUPÉREZ',
                  style: TextStyle(letterSpacing: 1.4, fontWeight: FontWeight.w800, color: step.run ? c.onCard : c.ink)),
              Text(step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kDisplay, fontSize: 28, fontWeight: FontWeight.w800, color: step.run ? c.onCard : c.ink)),
              if (step.distance != null)
                Text(step.distance!, style: TextStyle(fontWeight: FontWeight.w700, color: step.run ? c.onCard : c.ink)),
              Semantics(
                liveRegion: true,
                child: Text('${left.ceil()}',
                    style: TextStyle(
                        fontFamily: kDisplay,
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: step.run ? c.onCard : c.ink,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              Text('secondes', style: TextStyle(color: step.run ? c.onCard : c.ink)),
            ]),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(value: left / step.seconds, minHeight: 8, backgroundColor: c.surface2, color: c.card),
          ),
          const SizedBox(height: 8),
          Text(next == null ? 'Ensuite : fin de la séance' : 'Ensuite : ${next.label}${next.distance == null ? '' : ' · ${next.distance}'} · ${next.seconds} s',
              style: TextStyle(color: c.muted)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(flex: 2, child: FilledButton(onPressed: _toggle, child: Text(running ? 'Pause' : (i == 0 && left == plan.first.seconds ? 'Démarrer' : 'Reprendre')))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: () => setState(_next), child: const Text('Passer'))),
          ]),
          const SizedBox(height: 14),
          Text('Le téléphone vibre à chaque changement. Le test officiel suit le fichier audio de la CRA.',
              style: TextStyle(fontSize: 12.5, color: c.muted)),
        ],
      ]),
    );
  }
}
