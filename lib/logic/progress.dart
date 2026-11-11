import '../models/user_data.dart';

class LevelInfo {
  const LevelInfo(this.name, this.min, this.next, this.nextName);
  final String name;
  final int min;
  final int? next;
  final String? nextName;

  double progress(int xp) => next == null ? 1 : ((xp - min) / (next! - min)).clamp(0, 1).toDouble();
}

const _levels = <(int, String)>[
  (0, 'Stagiaire'),
  (300, 'District'),
  (800, 'Ligue'),
  (1600, 'Régional'),
  (3000, 'Fédéral'),
  (5000, 'Élite'),
];

LevelInfo levelFor(int xp) {
  var i = 0;
  for (var k = 0; k < _levels.length; k++) {
    if (xp >= _levels[k].$1) i = k;
  }
  final next = i + 1 < _levels.length ? _levels[i + 1] : null;
  return LevelInfo(_levels[i].$2, _levels[i].$1, next?.$1, next?.$2);
}

class BadgeDef {
  const BadgeDef(this.id, this.name, this.description, this.test);
  final String id, name, description;
  final bool Function(UserData d) test;
}

final badgeDefs = <BadgeDef>[
  BadgeDef('first', 'Coup d’envoi', 'Terminer une première séance', (d) => d.sessions.isNotEmpty),
  BadgeDef('streak7', 'Régularité', '7 jours de suite', (d) => d.profile.streak >= 7),
  BadgeDef('perfect', 'Sans faute', '100 % sur 5 questions ou plus',
      (d) => d.sessions.any((s) => s.total >= 5 && s.correct == s.total)),
  BadgeDef('lynx', 'Œil de lynx', '25 hors-jeu bien jugés', (d) => d.offside.correct >= 25),
  BadgeDef('law11', 'Maître du hors-jeu', 'Loi 11 validée sur 10 réponses ou plus',
      (d) => d.law(11).total >= 10 && (d.law(11).ratio ?? 0) >= .75),
  BadgeDef('all17', 'Tour complet', 'Avoir travaillé les 17 lois',
      (d) => List.generate(17, (i) => i + 1).every((l) => d.law(l).total > 0)),
  BadgeDef('exam', 'Reçu', 'Réussir un examen blanc', (d) => d.sessions.any((s) => s.isExam && (s.passed ?? false))),
  BadgeDef('carnet', 'Carnet tenu', '5 matchs au carnet', (d) => d.matches.length >= 5),
];

/// Ajoute les badges nouvellement mérités et les renvoie.
List<BadgeDef> awardBadges(UserData d) {
  final fresh = <BadgeDef>[];
  for (final b in badgeDefs) {
    if (!d.badges.contains(b.id) && b.test(d)) {
      d.badges.add(b.id);
      fresh.add(b);
    }
  }
  return fresh;
}

/// Points d'expérience gagnés pour une séance.
int sessionXp({required int correct, required int total, bool timed = false, bool examPassed = false}) =>
    correct * 10 + (timed ? correct * 5 : 0) + (correct == total && total >= 5 ? 20 : 0) + (examPassed ? 100 : 0);

/// Série de jours consécutifs : +1 si la dernière activité date d'hier,
/// inchangée si c'est aujourd'hui, 1 sinon.
int nextStreak({required int streak, required String? lastActive, required String today, required String yesterday}) {
  if (lastActive == today) return streak;
  if (lastActive == yesterday) return streak + 1;
  return 1;
}
