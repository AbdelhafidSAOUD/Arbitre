import 'dart:math';

import '../models/content.dart';
import 'categories.dart';

/// Poids d'une question selon le profil : un débutant reçoit surtout des
/// questions simples, un arbitre confirmé des cas difficiles, un assistant
/// davantage de questions qui le concernent. Les lois mal maîtrisées
/// ressortent plus souvent.
double questionWeight(
  Question q, {
  required String level,
  required String role,
  double? lawAccuracy,
}) {
  var w = 1.0;
  switch (tierFor(level)) {
    case Tier.beginner:
      w = switch (q.difficulty) { 1 => 3, 2 => 1.4, _ => .35 };
    case Tier.expert:
      w = switch (q.difficulty) { 3 => 3, 2 => 2, _ => .7 };
    case Tier.confirmed:
      break;
  }
  if (q.roleTag == 'assistant' && role != 'central') w *= 2;
  if (lawAccuracy != null && lawAccuracy < .6) w *= 1.4;
  return w;
}

/// Tirage pondéré sans remise (méthode d'Efraimidis–Spirakis).
List<T> weightedSample<T>(List<T> pool, int n, double Function(T) weight, Random rng) {
  final keyed = [
    for (final item in pool)
      (item: item, key: pow(rng.nextDouble(), 1 / max(weight(item), 1e-6)).toDouble()),
  ]..sort((a, b) => b.key.compareTo(a.key));
  return keyed.take(n).map((e) => e.item).toList();
}
