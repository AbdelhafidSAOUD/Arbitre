import '../logic/offside.dart';

const lawNames = <String>[
  'Le terrain',
  'Le ballon',
  'Les joueurs',
  'L’équipement des joueurs',
  'L’arbitre',
  'Les autres arbitres',
  'La durée du match',
  'Coup d’envoi et reprise du jeu',
  'Ballon en jeu et hors du jeu',
  'L’issue d’un match',
  'Le hors-jeu',
  'Fautes et incorrections',
  'Les coups francs',
  'Le penalty',
  'La rentrée de touche',
  'Le coup de pied de but',
  'Le coup de pied de coin',
];

String lawName(int law) => (law >= 1 && law <= 17) ? lawNames[law - 1] : 'Loi $law';

class Question {
  const Question({
    required this.id,
    required this.law,
    required this.kind,
    required this.difficulty,
    required this.text,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    this.roleTag,
    this.edition = '2025/26',
    this.offside,
  });

  final String id;
  final int law;
  final String kind; // connaissance | situation
  final int difficulty; // 1 à 3
  final String? roleTag; // "assistant" ou null
  final String text;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String edition;
  final OffsideScenario? offside;

  bool get isOffside => offside != null;

  String get kindLabel => isOffside
      ? 'Simulateur'
      : kind == 'situation'
          ? 'Situation'
          : 'Connaissance';

  /// Vérifie qu'une question venue du serveur est exploitable.
  bool get isValid =>
      id.isNotEmpty &&
      law >= 1 &&
      law <= 17 &&
      options.length >= 2 &&
      answerIndex >= 0 &&
      answerIndex < options.length &&
      text.isNotEmpty;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
        id: j['id'] as String,
        law: (j['law'] as num).toInt(),
        kind: (j['kind'] as String?) ?? 'connaissance',
        difficulty: ((j['difficulty'] as num?) ?? 1).toInt(),
        roleTag: j['role_tag'] as String?,
        text: j['question'] as String,
        options: (j['options'] as List).map((e) => e.toString()).toList(),
        answerIndex: (j['answer_index'] as num).toInt(),
        explanation: (j['explanation'] as String?) ?? '',
        edition: (j['laws_edition'] as String?) ?? '2025/26',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'law': law,
        'kind': kind,
        'difficulty': difficulty,
        'role_tag': roleTag,
        'question': text,
        'options': options,
        'answer_index': answerIndex,
        'explanation': explanation,
        'laws_edition': edition,
      };
}

class Lesson {
  const Lesson({required this.law, required this.title, required this.points});
  final int law;
  final String title;
  final List<String> points;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        law: (j['law'] as num).toInt(),
        title: j['title'] as String,
        points: (j['points'] as List).map((e) => e.toString()).toList(),
      );

  Map<String, dynamic> toJson() => {'law': law, 'title': title, 'points': points};
}

class Track {
  const Track(this.name, this.description, this.laws);
  final String name;
  final String description;
  final List<int> laws;
}

const tracks = <Track>[
  Track('Les fondamentaux', 'Terrain, ballon, joueurs, équipement', [1, 2, 3, 4]),
  Track('L’équipe arbitrale et le temps', 'Pouvoirs de l’arbitre, assistants, VAR, durée', [5, 6, 7]),
  Track('Le jeu en mouvement', 'Reprises, ballon en jeu, but, hors-jeu', [8, 9, 10, 11]),
  Track('Fautes et sanctions', 'Le cœur du métier d’arbitre', [12]),
  Track('Les coups de pied arrêtés', 'Coups francs, penalty, touche, but, coin', [13, 14, 15, 16, 17]),
];
