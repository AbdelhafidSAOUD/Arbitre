import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../config.dart';
import '../logic/quiz.dart';
import '../models/content.dart';
import '../theme.dart';
import 'common.dart';
import 'pitch.dart';

Future<void> startQuiz(BuildContext context, QuizConfig config) async {
  final state = AppScope.read(context);
  final items = state.buildQuiz(config);
  if (items.isEmpty) {
    showMessage(context, 'Aucune question disponible pour cette séance.');
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => QuizScreen(config: config, items: items),
    fullscreenDialog: true,
  ));
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.config, required this.items});
  final QuizConfig config;
  final List<QuizItem> items;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int index = 0;
  bool revealed = false; // séance en salle : réponse affichée
  Timer? _timer;
  double timeLeft = 1; // fraction restante du chrono par question
  late DateTime examDeadline;
  Duration examLeft = Duration.zero;
  final _focus = FocusNode();

  QuizConfig get c => widget.config;
  QuizItem get item => widget.items[index];
  bool get feedbackShown => !c.exam && !c.classroom && item.answered;

  @override
  void initState() {
    super.initState();
    if (c.exam) {
      examDeadline = DateTime.now().add(const Duration(minutes: AppConfig.examMinutes));
      _tickExam();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tickExam());
    } else if (c.timed) {
      _startQuestionTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _tickExam() {
    final left = examDeadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      _timer?.cancel();
      _finish(timeUp: true);
      return;
    }
    setState(() => examLeft = left);
  }

  void _startQuestionTimer() {
    _timer?.cancel();
    final start = DateTime.now();
    const total = Duration(seconds: AppConfig.secondsPerQuestion);
    setState(() => timeLeft = 1);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final left = 1 - DateTime.now().difference(start).inMilliseconds / total.inMilliseconds;
      if (left <= 0) {
        t.cancel();
        _timeout();
      } else {
        setState(() => timeLeft = left);
      }
    });
  }

  void _timeout() {
    if (item.answered) return;
    setState(() => item.timeout = true);
    AppScope.read(context).recordAnswer(item.question, false, c.label);
  }

  void _pick(int pos) {
    if (c.classroom) return;
    if (c.exam) {
      setState(() => item.pickedPos = pos);
      return;
    }
    if (item.answered) return;
    _timer?.cancel();
    setState(() => item.pickedPos = pos);
    HapticFeedback.selectionClick();
    AppScope.read(context).recordAnswer(item.question, item.correct, c.label);
  }

  void _next() {
    if (index + 1 < widget.items.length) {
      setState(() {
        index++;
        revealed = false;
      });
      if (c.timed) _startQuestionTimer();
    } else {
      _finish();
    }
  }

  void _finish({bool timeUp = false}) {
    _timer?.cancel();
    if (c.classroom) {
      Navigator.of(context).pop();
      return;
    }
    final outcome = AppScope.read(context).completeSession(c, widget.items);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(config: c, items: widget.items, outcome: outcome, timeUp: timeUp),
    ));
  }

  Future<bool> _confirmQuit() async {
    if (!c.exam) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter l’examen ?'),
        content: const Text('Vos réponses ne seront pas enregistrées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuer l’examen')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitter')),
        ],
      ),
    );
    return ok ?? false;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey.keyLabel.toUpperCase();
    final i = 'ABCD'.indexOf(k);
    if (i >= 0 && i < item.order.length) {
      _pick(i);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter) {
      if (c.classroom && !revealed) {
        setState(() => revealed = true);
      } else if (feedbackShown || (c.classroom && revealed) || (c.exam && item.pickedPos != null)) {
        _next();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final sc = context.sc;
    final q = item.question;
    final mins = examLeft.inMinutes, secs = examLeft.inSeconds % 60;
    return PopScope(
      canPop: !c.exam,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) Navigator.of(context).pop();
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Quitter la séance',
              icon: const Icon(Icons.close),
              onPressed: () async {
                if (await _confirmQuit() && context.mounted) Navigator.of(context).pop();
              },
            ),
            titleSpacing: 0,
            title: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: index / widget.items.length,
                    minHeight: 8,
                    backgroundColor: sc.line,
                    color: sc.pitch,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${index + 1}/${widget.items.length}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: sc.muted, fontFeatures: const [FontFeature.tabularFigures()])),
              if (c.exam) ...[
                const SizedBox(width: 12),
                Text('$mins:${secs.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontFamily: kDisplay,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: examLeft.inSeconds < 120 ? sc.red : sc.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ],
              const SizedBox(width: 16),
            ]),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                if (c.timed && !item.answered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: timeLeft,
                        minHeight: 6,
                        backgroundColor: sc.line,
                        color: timeLeft < 1 / 3 ? sc.red : sc.card,
                      ),
                    ),
                  ),
                Panel(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        Pill('Loi ${q.law} · ${lawName(q.law)}'),
                        Pill(q.kindLabel, tone: q.kind == 'situation' ? Tone.mid : Tone.ok),
                        if (q.difficulty == 3) const Pill('Expert', tone: Tone.ko),
                      ]),
                      const SizedBox(height: 14),
                      if (q.offside != null) ...[
                        OffsidePitch(scenario: q.offside!, reveal: feedbackShown || (c.classroom && revealed)),
                        const SizedBox(height: 14),
                      ],
                      Text(q.text,
                          style: TextStyle(fontSize: c.classroom ? 24 : 20, fontWeight: FontWeight.w600, height: 1.35)),
                      const SizedBox(height: 14),
                      for (var pos = 0; pos < item.order.length; pos++) ...[
                        _OptionButton(
                          letter: 'ABCD'[pos],
                          text: q.options[item.order[pos]],
                          state: _optionState(pos),
                          onTap: (feedbackShown || c.classroom) ? null : () => _pick(pos),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ..._footer(sc, q),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _OptState _optionState(int pos) {
    final showAnswer = feedbackShown || (c.classroom && revealed);
    if (showAnswer) {
      if (pos == item.correctPos) return _OptState.right;
      if (pos == item.pickedPos) return _OptState.wrong;
      return _OptState.idle;
    }
    if (c.exam && item.pickedPos == pos) return _OptState.picked;
    return _OptState.idle;
  }

  List<Widget> _footer(SiffletColors sc, Question q) {
    final last = index + 1 == widget.items.length;
    if (c.classroom) {
      if (!revealed) {
        return [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: sc.ink, foregroundColor: sc.bg),
            onPressed: () => setState(() => revealed = true),
            child: const Text('Révéler la réponse'),
          ),
          const SizedBox(height: 8),
          Text('Laissez la salle voter à main levée (A, B, C, D) avant de révéler.',
              style: TextStyle(fontSize: 13, color: sc.muted)),
        ];
      }
      return [
        _Explanation(
          good: true,
          title: 'Réponse ${'ABCD'[item.correctPos]} : ${q.options[q.answerIndex]}',
          body: q.explanation,
          footnote: 'Référence : loi ${q.law}, ${lawName(q.law)}',
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _next, child: Text(last ? 'Terminer la séance' : 'Question suivante')),
      ];
    }
    if (c.exam) {
      return [
        Text('Examen : correction à la fin uniquement. Vous pouvez changer d’avis avant de valider.',
            style: TextStyle(fontSize: 13, color: sc.muted)),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: item.pickedPos == null ? null : _next,
          child: Text(last ? 'Terminer l’examen' : 'Valider et continuer'),
        ),
      ];
    }
    if (!item.answered) return [];
    final ok = item.correct;
    return [
      _Explanation(
        good: ok,
        title: ok ? 'Bonne décision' : (item.timeout ? 'Temps écoulé' : 'Mauvaise décision'),
        body: q.explanation,
        footnote: 'Référence : loi ${q.law}, ${lawName(q.law)}'
            '${!ok && !q.isOffside ? ' · Cette question reviendra demain en révision.' : ''}',
      ),
      const SizedBox(height: 14),
      FilledButton(onPressed: _next, child: Text(last ? 'Voir mon résultat' : 'Question suivante')),
    ];
  }
}

enum _OptState { idle, picked, right, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.letter, required this.text, required this.state, this.onTap});
  final String letter, text;
  final _OptState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final (border, bg, keyBg, keyFg) = switch (state) {
      _OptState.right => (c.pitch, c.pitchSoft, c.pitch, Colors.white),
      _OptState.wrong => (c.red, c.redSoft, c.red, Colors.white),
      _OptState.picked => (c.ink, c.surface2, c.ink, c.bg),
      _OptState.idle => (c.line, c.surface, c.surface2, c.ink),
    };
    return Semantics(
      button: true,
      label: 'Réponse $letter : $text${state == _OptState.right ? ', bonne réponse' : state == _OptState.wrong ? ', mauvaise réponse' : ''}',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: keyBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: state == _OptState.idle ? c.line : keyBg)),
                child: Text(letter, style: TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w800, color: keyFg)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.good, required this.title, required this.body, required this.footnote});
  final bool good;
  final String title, body, footnote;
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      liveRegion: true,
      child: Panel(
        color: c.surface2,
        borderColor: good ? c.pitch : c.red,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: TextStyle(fontFamily: kDisplay, fontSize: 20, fontWeight: FontWeight.w800, color: good ? c.pitch : c.red)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 6),
          Text(footnote, style: TextStyle(fontSize: 13, color: c.muted)),
        ]),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.config, required this.items, required this.outcome, this.timeUp = false});
  final QuizConfig config;
  final List<QuizItem> items;
  final SessionOutcome outcome;
  final bool timeUp;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final o = outcome;
    final ratio = o.correct / o.total;
    final need = (AppConfig.examPassRatio * o.total).ceil();
    final message = o.exam
        ? (o.passed! ? 'Examen réussi (seuil : $need/${o.total}).' : 'Examen non réussi : il fallait $need/${o.total}.')
        : ratio == 1
            ? 'Sans faute. Prêt pour le terrain.'
            : ratio >= .7
                ? 'Solide. Quelques points à revoir.'
                : ratio >= .5
                    ? 'Correct. Revoyez les explications ci-dessous.'
                    : 'À retravailler. Les fiches sont faites pour ça.';
    final wrong = items.where((i) => !i.correct).toList();
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Eyebrow(config.label)),
      body: PageList(children: [
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${o.correct}', style: TextStyle(fontSize: 76, color: c.ink)),
            TextSpan(text: '/${o.total}', style: TextStyle(fontSize: 34, color: c.muted)),
          ]),
          style: const TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w800, height: .95),
        ),
        const SizedBox(height: 8),
        Text(message.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('+${o.xp} XP · ${o.totalXp} XP au total${timeUp ? ' · Temps écoulé' : ''}', style: TextStyle(color: c.muted)),
        if (o.newBadges.isNotEmpty) ...[
          const SizedBox(height: 16),
          ListBox(children: [
            for (final b in o.newBadges)
              Row2(
                leading: _Star(),
                title: 'Badge débloqué : ${b.name}',
                subtitle: b.description,
              ),
          ]),
        ],
        if (wrong.isNotEmpty) ...[
          SectionTitle(o.exam ? 'Correction de vos erreurs' : 'Vos erreurs'),
          ListBox(children: [
            for (final w in wrong)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LawNumber(w.question.law),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(w.question.isOffside ? 'Simulateur : position de l’attaquant' : w.question.text,
                          style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
                      const SizedBox(height: 4),
                      Text('Réponse : ${w.question.options[w.question.answerIndex]}', style: TextStyle(fontSize: 13, color: c.pitch, fontWeight: FontWeight.w600)),
                      if (o.exam) ...[
                        const SizedBox(height: 4),
                        Text(w.question.explanation, style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    ]),
                  ),
                ]),
              ),
          ]),
          if (wrong.any((w) => !w.question.isOffside)) ...[
            const SizedBox(height: 8),
            Text('Ces questions sont ajoutées à vos révisions espacées.', style: TextStyle(fontSize: 13, color: c.muted)),
          ],
        ],
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Terminer'))),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                final state = AppScope.read(context);
                final again = state.buildQuiz(config);
                if (again.isEmpty) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => QuizScreen(config: config, items: again)));
              },
              child: const Text('Rejouer'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Star extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: context.sc.card, shape: BoxShape.circle),
        child: Icon(Icons.star_rounded, color: context.sc.onCard),
      );
}
