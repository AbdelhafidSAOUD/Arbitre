import '../models/content.dart';
import 'progress.dart';

/// Paramètres d'une séance d'entraînement.
class QuizConfig {
  const QuizConfig({
    required this.label,
    this.count = 10,
    this.offsideCount = 0,
    this.laws,
    this.questionIds,
    this.timed = false,
    this.exam = false,
    this.classroom = false,
    this.offsideOnly = false,
  });

  final String label;
  final int count;
  final int offsideCount;
  final List<int>? laws;
  final List<String>? questionIds;
  final bool timed, exam, classroom, offsideOnly;
}

class QuizItem {
  QuizItem(this.question, this.order);
  final Question question;

  /// Ordre d'affichage des réponses (indices dans question.options).
  final List<int> order;
  int? pickedPos;
  bool timeout = false;

  bool get answered => pickedPos != null || timeout;
  bool get correct => !timeout && pickedPos != null && order[pickedPos!] == question.answerIndex;
  int get correctPos => order.indexOf(question.answerIndex);
}

class SessionOutcome {
  const SessionOutcome({
    required this.correct,
    required this.total,
    required this.xp,
    required this.totalXp,
    required this.newBadges,
    this.exam = false,
    this.passed,
  });
  final int correct, total, xp, totalXp;
  final List<BadgeDef> newBadges;
  final bool exam;
  final bool? passed;
}
