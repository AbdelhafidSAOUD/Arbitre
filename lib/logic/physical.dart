import '../models/user_data.dart';

/// Tests physiques des arbitres de ligue, saison 2025/26 (tableau de la CRA).
/// Les barèmes varient d'une ligue à l'autre : ils sont donnés ici comme
/// référence et l'arbitre peut toujours saisir son résultat librement.
class PhysicalTest {
  const PhysicalTest({
    required this.id,
    required this.name,
    required this.forWho,
    required this.procedure,
    required this.training,
    required this.thresholds,
    this.unit = TestUnit.seconds,
  });
  final String id, name, forWho, procedure, training;
  final List<TestThreshold> thresholds;
  final TestUnit unit;
}

enum TestUnit { seconds, stage }

/// Exigence pour une catégorie : un temps maximal (secondes) ou un palier.
class TestThreshold {
  const TestThreshold(this.who, this.label, {this.maxSeconds, this.stage, this.distance});
  final String who, label;
  final double? maxSeconds;
  final String? stage; // « 14-8 »
  final ({double single, double half})? distance; // S.D.S. : A→D et D→P
}

const physicalTests = <PhysicalTest>[
  PhysicalTest(
    id: 'sprint40',
    name: 'Sprint 40 m',
    forWho: 'Centraux candidats F5, R1 promo, JAF',
    procedure: '2 sprints de 40 m, départ arrêté pied avant sur la ligne, 1,5 m avant la cellule. '
        '90 s de récupération au maximum, en revenant au départ en marchant. Un échec : un 3e essai. '
        'Deux échecs sur trois : test non réussi.',
    training: '6 sprints de 40 m, récupération complète (au moins 90 s). Chronométrez avec un partenaire.',
    thresholds: [
      TestThreshold('Candidat F5, R1 promo, JAF, candidat JAF', '6"20', maxSeconds: 6.20),
      TestThreshold('Candidates FFE3, JAFFE', '6"60', maxSeconds: 6.60),
    ],
  ),
  PhysicalTest(
    id: 'sds',
    name: 'S.D.S. (simple, double, simple)',
    forWho: 'Tous les arbitres centraux',
    procedure: 'Au rythme du fichier audio : courir A → D en 12 s, récupérer 6 s ; aller-retour D → P → D en 16 s, '
        'récupérer 6 s ; D → A en 12 s, récupérer 24 s. 5 répétitions par bloc, 3 blocs, 1 min entre les blocs. '
        'Un départ anticipé ou un retard : carton jaune ; le deuxième : élimination.',
    training: 'Lancez la séance guidée : elle reprend les temps du test, à vos distances.',
    unit: TestUnit.stage,
    thresholds: [
      TestThreshold('Candidat F5, JAF, R1', '56 m / 34 m', distance: (single: 56, half: 34)),
      TestThreshold('R2', '54 m / 32 m', distance: (single: 54, half: 32)),
      TestThreshold('R3 et R3 stagiaire', '53 m / 31,5 m', distance: (single: 53, half: 31.5)),
      TestThreshold('JAR et JAR stagiaire', '52 m / 31 m', distance: (single: 52, half: 31)),
      TestThreshold('Féminines', '52 m / 31 m', distance: (single: 52, half: 31)),
    ],
  ),
  PhysicalTest(
    id: 'sprint30',
    name: 'Sprint 30 m',
    forWho: 'Arbitres assistants',
    procedure: '2 sprints de 30 m, élan de 1,5 m, 90 s de récupération au maximum. Un échec : un 3e essai. '
        'Deux échecs sur trois : test non réussi.',
    training: '6 sprints de 30 m, départ arrêté, récupération complète. Travaillez les 5 premiers mètres.',
    thresholds: [
      TestThreshold('Assistants promotionnels', '4"70', maxSeconds: 4.70),
      TestThreshold('Assistants R1', '4"90', maxSeconds: 4.90),
      TestThreshold('Assistants R2 et R2 stagiaire', '5"00', maxSeconds: 5.00),
    ],
  ),
  PhysicalTest(
    id: 'coda',
    name: 'C.O.D.A.',
    forWho: 'Arbitres assistants',
    procedure: '10 m en course avant (A → C), 8 m en pas chassés à gauche (C → B), 8 m en pas chassés à droite '
        '(B → C), 10 m en course avant (C → A). Départ 0,5 m avant la cellule. 2 courses.',
    training: '6 C.O.D.A. chronométrés, 90 s de récupération en marchant. '
        'Soignez la transition course avant / pas chassés, sans croiser les pieds.',
    thresholds: [
      TestThreshold('Assistants promotionnels', '10"00', maxSeconds: 10.00),
      TestThreshold('Assistants R1', '10"20', maxSeconds: 10.20),
      TestThreshold('Assistants R2 et R2 stagiaire', '10"50', maxSeconds: 10.50),
    ],
  ),
  PhysicalTest(
    id: 'ariet',
    name: 'A.R.I.E.T.',
    forWho: 'Arbitres assistants',
    procedure: 'Au rythme du fichier audio : 20 m aller-retour en course, 2,5 m aller-retour en marchant, '
        '12,5 m aller-retour en pas chassés sans se retourner, 2,5 m aller-retour en marchant, '
        'jusqu’au palier exigé.',
    training: 'Le test se court sur fichier audio. À l’entraînement : 3 × 6 min de cycles course 20 m / '
        'pas chassés 12,5 m, 2 min de récupération.',
    unit: TestUnit.stage,
    thresholds: [
      TestThreshold('Assistants promotionnels', 'Palier 16-3 · 1 470 m', stage: '16-3'),
      TestThreshold('Assistants R1', 'Palier 15-3 · 1 170 m', stage: '15-3'),
      TestThreshold('Assistants R2 et R2 stagiaire', 'Palier 14-8 · 975 m', stage: '14-8'),
    ],
  ),
];

PhysicalTest testById(String id) => physicalTests.firstWhere((t) => t.id == id);

/// Tests à passer selon la fonction et le niveau précis de l'arbitre, avec
/// l'exigence qui le concerne.
List<(PhysicalTest, TestThreshold)> testsFor(Profile p) {
  final lv = (p.levelDetail ?? '').toUpperCase();
  if (p.isAssistant) {
    final k = lv.contains('R1') ? 1 : (lv.contains('PROMO') || lv.contains('F5') || lv.startsWith('F')) ? 0 : 2;
    return [for (final id in ['sprint30', 'coda', 'ariet']) (testById(id), testById(id).thresholds[k])];
  }
  final sds = testById('sds');
  final k = lv.contains('R2')
      ? 1
      : lv.contains('R3')
          ? 2
          : lv.contains('JAR')
              ? 3
              : 0;
  final needsSprint = lv.contains('R1') || lv.contains('F5') || lv.contains('JAF') || lv.contains('PROMO');
  return [
    (sds, sds.thresholds[k]),
    if (needsSprint) (testById('sprint40'), testById('sprint40').thresholds[0]),
  ];
}

/// Lit un temps saisi : « 4,88 », « 4.88 », « 4"88 ».
double? parseSeconds(String v) => double.tryParse(v.trim().replaceAll('"', '.').replaceAll(',', '.'));

/// Compare deux paliers « 15-3 » (palier, puis répétition).
int compareStage(String a, String b) {
  List<double> parts(String s) => s.split(RegExp(r'[-–]')).map((x) => double.tryParse(x.trim().replaceAll(',', '.')) ?? 0).toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 2; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Résultat validé ? null si la saisie ne peut pas être comparée.
bool? passes(TestThreshold t, String value) {
  if (t.maxSeconds != null) {
    final s = parseSeconds(value);
    return s == null ? null : s <= t.maxSeconds! + 1e-9;
  }
  if (t.stage != null) {
    if (!RegExp(r'^\s*\d+([.,]\d+)?\s*[-–]\s*\d+\s*$').hasMatch(value)) return null;
    return compareStage(value, t.stage!) >= 0;
  }
  return null;
}

/// Une étape de la séance S.D.S. guidée.
class SdsStep {
  const SdsStep(this.label, this.seconds, {this.distance, this.run = false, required this.block, required this.rep});
  final String label;
  final int seconds;
  final String? distance;
  final bool run;
  final int block, rep;
}

String _m(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',')} m';

/// Séquence complète du S.D.S. : 3 blocs de 5 répétitions.
List<SdsStep> sdsPlan(({double single, double half}) d) {
  final out = <SdsStep>[];
  for (var b = 1; b <= 3; b++) {
    for (var r = 1; r <= 5; r++) {
      out
        ..add(SdsStep('Simple A → D', 12, distance: _m(d.single), run: true, block: b, rep: r))
        ..add(SdsStep('Récupération', 6, block: b, rep: r))
        ..add(SdsStep('Double D → P → D', 16, distance: '2 × ${_m(d.half)}', run: true, block: b, rep: r))
        ..add(SdsStep('Récupération', 6, block: b, rep: r))
        ..add(SdsStep('Simple D → A', 12, distance: _m(d.single), run: true, block: b, rep: r))
        ..add(SdsStep('Récupération', 24, block: b, rep: r));
    }
    if (b < 3) out.add(SdsStep('Pause entre les blocs', 60, block: b, rep: 5));
  }
  return out;
}
