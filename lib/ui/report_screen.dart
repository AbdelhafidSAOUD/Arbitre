import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../logic/report.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'common.dart';

/// Atelier de rédaction du rapport disciplinaire, avec correction et
/// rapport modèle annoté.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late List<ReportCase> cases;
  late ReportCase current;
  final _text = TextEditingController();
  ReportFeedback? feedback;
  bool showModel = false;
  Timer? _save;
  final _recorded = <String>{}; // une note enregistrée par cas et par visite

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    cases = s.content.reportCases;
    current = cases.first;
    _text.text = s.reportDraft(current.id);
  }

  @override
  void dispose() {
    _save?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _select(ReportCase c) {
    final s = AppScope.read(context);
    s.saveReportDraft(current.id, _text.text);
    setState(() {
      current = c;
      _text.text = s.reportDraft(c.id);
      feedback = null;
      showModel = false;
    });
  }

  void _onChanged(String v) {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 600), () => AppScope.read(context).saveReportDraft(current.id, v));
    // Reconstruit l'écran : bouton « Corriger », alerte sur les données
    // personnelles et correction en direct suivent la saisie.
    setState(() {
      if (feedback != null) feedback = analyseReport(v, current);
    });
  }

  void _correct() {
    final f = analyseReport(_text.text, current);
    setState(() => feedback = f);
    if (f.words >= 20 && _recorded.add(current.id)) {
      AppScope.read(context).recordScoredSession(Labels.report, f.score, 20);
    }
  }

  void _anonymise() {
    final t = anonymiseReport(_text.text);
    _text.text = t;
    _onChanged(t);
    setState(() => feedback = feedback == null ? null : analyseReport(t, current));
  }

  static const _partColors = ['card', 'blue', 'red', 'pitch', 'grey'];

  Color _partBg(SiffletColors c, int i) => switch (_partColors[i]) {
        'card' => c.cardSoft,
        'blue' => c.attacker.withValues(alpha: .14),
        'red' => c.redSoft,
        'pitch' => c.pitchSoft,
        _ => c.surface2,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final f = feedback;
    final personal = analyseReport(_text.text, current).personalData;
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport disciplinaire')),
      body: PageList(children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final rc in cases) ChoiceChip(label: Text(rc.title), selected: rc.id == current.id, onSelected: (_) => _select(rc)),
        ]),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (k, v) in current.facts)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 96, child: Text(k, style: TextStyle(color: c.muted))),
                  Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            const SizedBox(height: 6),
            Text(current.story),
          ]),
        ),
        const SizedBox(height: 10),
        Panel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            shape: const Border(),
            title: const Text('La méthode de la DTA', style: TextStyle(fontWeight: FontWeight.w700)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _Bullet('CQQCOQP', 'Comment, Quoi, Qui, Combien, Où, Quand, Pourquoi.'),
              _Bullet('Plan en 5 temps',
                  '1. chapeau de présentation · 2. situation dans le temps et l’espace · 3. description des faits · '
                      '4. sanctions et leur mise en œuvre · 5. reprise du jeu et informations diverses.'),
              _Bullet('Écrire au présent', 'Décrire sans interpréter, respecter la chronologie. Un schéma du terrain au brouillon aide.'),
              _Bullet('Erreurs fréquentes',
                  'Oublier le chapeau ou la reprise, mélanger deux situations, mal conjuguer AVERTIR (j’avertis) et EXCLURE (j’exclus, il est exclu).'),
              _Bullet('À l’examen', 'F4, AAF3, JAF : 45 min, 2 visionnages, note sur 20, éliminatoire sous 6.'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _text,
          onChanged: _onChanged,
          minLines: 9,
          maxLines: 20,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Votre rapport',
            hintText: 'Exclusion de M. [NOM Prénom], joueur n° … de l’équipe …, à la …e minute, pour …',
            alignLabelWithHint: true,
            helperText: 'Brouillon gardé sur cet appareil uniquement',
          ),
        ),
        if (personal) ...[
          const SizedBox(height: 8),
          Panel(
            color: c.redSoft,
            borderColor: c.red,
            child: Row(children: [
              const Expanded(
                child: Text('Votre texte contient un nom ou un numéro de licence. Pour l’entraînement, remplacez-les.'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(style: compactButton, onPressed: _anonymise, child: const Text('Anonymiser')),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton(onPressed: wordCount(_text.text) < 5 ? null : _correct, child: const Text('Corriger mon rapport'))),
          const SizedBox(width: 8),
          OutlinedButton(
            style: compactButton,
            onPressed: () => setState(() => showModel = !showModel),
            child: Text(showModel ? 'Masquer le modèle' : 'Voir le modèle'),
          ),
        ]),
        if (f != null) ...[
          const SectionTitle('Correction'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Note indicative', style: TextStyle(fontWeight: FontWeight.w700))),
                Pill('${f.score} / 20', tone: f.score >= 14 ? Tone.ok : f.score >= ReportFeedback.passMark ? Tone.mid : Tone.ko),
              ]),
              if (f.score < ReportFeedback.passMark)
                Text('Sous la note éliminatoire de l’examen (6/20).', style: TextStyle(color: c.red, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (var i = 0; i < reportParts.length; i++)
                _Check(
                  ok: f.parts[i],
                  title: '${i + 1}. ${reportParts[i].name}',
                  detail: f.parts[i] ? null : reportParts[i].tip,
                  example: f.parts[i] ? null : current.model[i],
                ),
              if (current.hasWords)
                _Check(
                  ok: f.quotes,
                  title: 'Propos exacts entre guillemets',
                  detail: f.quotes ? null : 'Recopiez les mots tels qu’ils ont été dits, même grossiers.',
                ),
              if (f.judgments.isNotEmpty)
                _Check(
                  ok: false,
                  warn: true,
                  title: 'Jugements de valeur',
                  detail: 'Remplacez ${f.judgments.map((w) => '« $w »').join(', ')} par la description du geste.',
                ),
              if (f.conjugation.isNotEmpty) _Check(ok: false, warn: true, title: 'Conjugaison', detail: f.conjugation.join(' ; ')),
              if (f.pastForms >= 2)
                _Check(
                  ok: false,
                  warn: true,
                  title: 'Temps',
                  detail: 'Vous écrivez au passé (${f.pastForms} formes). La méthode conseille le présent : « il frappe », « j’exclus ».',
                ),
              const SizedBox(height: 6),
              Text('Correction automatique : elle vérifie la structure et la forme, pas l’exactitude des faits.',
                  style: TextStyle(fontSize: 12.5, color: c.muted)),
            ]),
          ),
        ],
        if (showModel) ...[
          const SectionTitle('Rapport modèle'),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < reportParts.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: _partBg(c, i), borderRadius: BorderRadius.circular(8)),
                    child: Text('${i + 1}. ${reportParts[i].name}', style: const TextStyle(fontSize: 12)),
                  ),
              ]),
              const SizedBox(height: 10),
              for (var i = 0; i < current.model.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _partBg(c, i), borderRadius: BorderRadius.circular(8)),
                  child: Text(current.model[i]),
                ),
              Text('Dans un vrai rapport, écrivez les nom, prénom et club. Dans l’application, les exemples restent anonymes.',
                  style: TextStyle(fontSize: 12.5, color: c.muted)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.title, this.text);
  final String title, text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$title : ', style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: text),
        ])),
      );
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.title, this.detail, this.example, this.warn = false});
  final bool ok, warn;
  final String title;
  final String? detail, example;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle : (warn ? Icons.error : Icons.radio_button_unchecked),
            size: 20, color: ok ? c.pitch : (warn ? c.red : c.muted)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (detail != null) Text(detail!, style: TextStyle(fontSize: 13, color: c.muted)),
            if (example != null)
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Exemple : ', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '« $example »'),
                ]),
                style: TextStyle(fontSize: 13, color: c.muted),
              ),
          ]),
        ),
      ]),
    );
  }
}
