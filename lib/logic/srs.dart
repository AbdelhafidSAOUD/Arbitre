import 'dates.dart';

/// Révisions espacées (système de Leitner à 5 boîtes).
/// Une erreur place la question en boîte 1 (à revoir demain). Chaque bonne
/// réponse la fait monter d'une boîte : revue après 2, 4, 8, puis 16 jours.
/// Réussie en boîte 5, elle est considérée comme acquise et sort du système.
const srsIntervals = [1, 2, 4, 8, 16];

class ReviewEntry {
  const ReviewEntry({required this.box, required this.due});
  final int box;
  final String due; // AAAA-MM-JJ

  Map<String, dynamic> toJson() => {'box': box, 'due': due};
  factory ReviewEntry.fromJson(Map<String, dynamic> j) =>
      ReviewEntry(box: (j['box'] as num).toInt(), due: j['due'] as String);
}

/// Résultat : [entry] est la nouvelle fiche (null = à retirer) et
/// [changed] indique s'il faut enregistrer quelque chose.
({ReviewEntry? entry, bool changed}) updateReview(
  ReviewEntry? current,
  bool correct, [
  DateTime? now,
]) {
  if (!correct) {
    return (entry: ReviewEntry(box: 1, due: addDaysIso(1, now)), changed: true);
  }
  if (current == null) return (entry: null, changed: false);
  final next = current.box + 1;
  if (next > srsIntervals.length) return (entry: null, changed: true);
  return (
    entry: ReviewEntry(box: next, due: addDaysIso(srsIntervals[next - 1], now)),
    changed: true,
  );
}

bool isDue(ReviewEntry e, [DateTime? now]) => e.due.compareTo(todayIso(now)) <= 0;
