/// Question au format des examens de la FFF : une situation, et l'arbitre
/// coche toutes les décisions à prendre (arrêt du jeu, sanction et motif,
/// reprise, rapport). Comme à l'examen, chaque élément oublié ou en trop
/// retire 0,25 point.
class ExamCase {
  const ExamCase({
    required this.id,
    required this.law,
    required this.source,
    required this.situation,
    required this.options,
    required this.answers,
    required this.explanation,
  });
  final String id, source, situation, explanation;
  final int law;
  final List<String> options;
  final Set<int> answers;

  factory ExamCase.fromJson(Map<String, dynamic> j) => ExamCase(
        id: j['id'] as String,
        law: (j['law'] as num).toInt(),
        source: j['source'] as String,
        situation: j['situation'] as String,
        options: [for (final o in j['options'] as List) o as String],
        answers: {for (final a in j['answers'] as List) (a as num).toInt()},
        explanation: j['explanation'] as String,
      );

  bool get isValid =>
      options.length >= 3 && answers.isNotEmpty && answers.every((a) => a >= 0 && a < options.length);

  /// Note de la question, sur 1 point.
  double score(Set<int> picked) {
    final missed = answers.difference(picked).length;
    final extra = picked.difference(answers).length;
    final s = 1 - 0.25 * (missed + extra);
    return s < 0 ? 0 : s;
  }
}
