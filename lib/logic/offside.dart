import 'dart:math';

import '../models/content.dart';

/// Un point sur le demi-terrain, en mètres.
/// x : de 0 à 68 (largeur). y : distance à la ligne de but adverse
/// (0 = ligne de but, 52,5 = ligne médiane). L'attaque se dirige vers y = 0.
class Pt {
  const Pt(this.x, this.y);
  final double x, y;
}

const double halfwayY = 52.5;
const double pitchWidth = 68;

enum OffsideType { offside, behindDefender, behindBall }

class OffsideScenario {
  OffsideScenario({
    required this.type,
    required this.goalkeeper,
    required this.secondDefender,
    required this.otherDefenders,
    required this.passer,
    required this.target,
    required this.decoys,
  });

  final OffsideType type;
  final Pt goalkeeper;
  final Pt secondDefender;
  final List<Pt> otherDefenders;
  final Pt passer;
  final Pt target;
  final List<Pt> decoys;

  /// Le ballon est dessiné au pied du passeur, légèrement devant lui.
  Pt get ball => Pt(passer.x + 1.3, passer.y - 1.1);

  List<Pt> get defenders => [goalkeeper, secondDefender, ...otherDefenders];

  /// Profondeur de l'avant-dernier adversaire (gardien compris).
  double get secondLastY {
    final ys = defenders.map((d) => d.y).toList()..sort();
    return ys[1];
  }

  /// Loi 11 : position de hors-jeu si, dans la moitié adverse, le joueur est
  /// plus près de la ligne de but adverse que le ballon et que
  /// l'avant-dernier adversaire. À la même hauteur : pas de hors-jeu.
  bool get isOffside =>
      target.y < halfwayY && target.y < secondLastY && target.y < ball.y;

  String get explanation {
    String m(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    if (isOffside) {
      return 'Position de hors-jeu : au moment de la passe, l’attaquant est '
          '${m(secondLastY - target.y)} m plus près de la ligne de but que '
          'l’avant-dernier défenseur, dans la moitié adverse et devant le ballon. '
          'L’infraction dépend ensuite de sa participation active au jeu.';
    }
    if (target.y >= secondLastY) {
      return 'Pas de position de hors-jeu : l’attaquant est '
          '${m(target.y - secondLastY)} m derrière l’avant-dernier défenseur '
          'au moment de la passe.';
    }
    return 'Pas de position de hors-jeu : le ballon est plus près de la ligne de '
        'but que l’attaquant (${m(target.y - ball.y)} m). Un joueur derrière le '
        'ballon ne peut pas être en position de hors-jeu, même devant '
        'l’avant-dernier défenseur.';
  }
}

/// Génère une situation de hors-jeu aléatoire et sans ambiguïté
/// (au moins 1,5 m d'écart avec la ligne de référence).
OffsideScenario generateOffside([Random? random]) {
  final rng = random ?? Random();
  double r(double a, double b) => a + rng.nextDouble() * (b - a);
  const types = [
    OffsideType.offside,
    OffsideType.offside,
    OffsideType.behindDefender,
    OffsideType.behindDefender,
    OffsideType.behindBall,
  ];
  final type = types[rng.nextInt(types.length)];
  final gk = Pt(r(31, 37), r(.8, 3));

  if (type == OffsideType.behindBall) {
    final left = rng.nextBool();
    final passer = Pt(left ? r(5, 12) : r(56, 63), r(3, 7));
    final ballY = passer.y - 1.1;
    final sd = Pt(r(26, 42), passer.y + r(6, 10));
    final target = Pt(left ? r(22, 34) : r(34, 46), r(passer.y + 1.6, sd.y - 1.6));
    assert(target.y > ballY);
    return OffsideScenario(
      type: type,
      goalkeeper: gk,
      secondDefender: sd,
      otherDefenders: [for (var i = 0; i < 3; i++) Pt(10 + i * 22 + r(-4, 4), sd.y + r(1, 6))],
      passer: passer,
      target: target,
      decoys: [Pt(r(20, 48), sd.y + r(3, 8))],
    );
  }

  final sdY = r(12, 30);
  final xs = [12.0, 26.0, 42.0, 56.0].map((x) => x + r(-3, 3)).toList()..shuffle(rng);
  final sd = Pt(xs[0], sdY);
  final others = [for (final x in xs.skip(1)) Pt(x, sdY + r(.4, 4.5))];
  final passer = Pt(r(18, 50), min(51, sdY + r(9, 18)));
  final dy = r(1.5, 4);
  final ty = type == OffsideType.offside ? sdY - dy : sdY + dy;
  final everyone = [gk, sd, ...others];
  var target = Pt(r(8, 60), ty);
  for (var i = 0; i < 30; i++) {
    final clash = everyone.any((p) => (p.x - target.x).abs() < 4 && (p.y - target.y).abs() < 4);
    if (!clash) break;
    target = Pt(r(8, 60), ty);
  }
  return OffsideScenario(
    type: type,
    goalkeeper: gk,
    secondDefender: sd,
    otherDefenders: others,
    passer: passer,
    target: target,
    decoys: [Pt(r(10, 58), sdY + r(2, 6))],
  );
}

Question offsideQuestion(OffsideScenario s) => Question(
      id: 'offside',
      law: 11,
      kind: 'situation',
      difficulty: 2,
      text: 'Au moment de la passe, l’attaquant entouré est-il en position de hors-jeu ?',
      options: const ['Oui, position de hors-jeu', 'Non, pas de position de hors-jeu'],
      answerIndex: s.isOffside ? 0 : 1,
      explanation: s.explanation,
      offside: s,
    );
