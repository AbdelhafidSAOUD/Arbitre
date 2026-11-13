import '../config.dart';
import '../logic/categories.dart';
import '../logic/dates.dart';
import '../logic/srs.dart';

const profileRoles = <String, String>{
  'central': 'Arbitre central',
  'assistant': 'Arbitre assistant',
  'mixte': 'Les deux',
};
const profileGoals = <String, String>{
  'progresser': 'Progresser au quotidien',
  'examen': 'Préparer un examen ou une promotion',
  'reprise': 'Reprendre après une pause',
  'former': 'Former d’autres arbitres',
};
const matchRoles = ['Arbitre central', 'Arbitre assistant', 'Quatrième arbitre'];

/// Critères d'auto-évaluation après match (clé en base, libellé).
const evalCriteria = <(String, String)>[
  ('placement', 'Placement'),
  ('physical', 'Condition physique'),
  ('laws', 'Application des lois'),
  ('management', 'Gestion des joueurs'),
  ('communication', 'Communication'),
  ('concentration', 'Concentration'),
];

/// Satisfaction après match, de 1 à 5.
const satisfactionLabels = ['', 'Très déçu', 'Déçu', 'Correct', 'Satisfait', 'Très satisfait'];

/// Points à travailler proposés au débriefing (l'arbitre peut en ajouter).
const workPointChoices = [
  'Lecture du hors-jeu',
  'Placement sur coups de pied arrêtés',
  'Placement dans le jeu',
  'Gestion des bancs',
  'Timing des cartons',
  'Concentration en fin de match',
  'Sprint de repli',
  'Communication avec l’équipe arbitrale',
  'Gestuelle et signaux',
  'Gestion des conflits',
];

class Profile {
  const Profile({
    this.firstName,
    this.country = 'FR',
    this.level = 'district',
    this.levelDetail,
    this.customCategory,
    this.role = 'central',
    this.alsoOther = false,
    this.goal = 'progresser',
    this.birthYear,
    this.parentalConsent = false,
    this.parentEmail,
    this.privacyAcceptedAt,
    this.privacyVersion,
    this.largeText = false,
    this.xp = 0,
    this.streak = 0,
    this.lastActive,
  });

  final String? firstName;
  final String country; // FR | MA
  /// Catégorie officielle (voir logic/categories.dart), ou « autre » :
  /// la catégorie saisie est alors dans [customCategory].
  final String level;
  final String? levelDetail; // niveau précis : R2, F4…
  final String? customCategory;
  final String role, goal;
  /// Officie aussi dans l'autre fonction (central et assistant).
  final bool alsoOther;
  final int? birthYear;
  final bool parentalConsent;
  final String? parentEmail;
  final String? privacyAcceptedAt;
  final String? privacyVersion;
  final bool largeText;
  final int xp, streak;
  final String? lastActive;

  static bool isMinorBirthYear(int? year, [DateTime? now]) {
    if (year == null) return false;
    // Prudence : l'année de naissance seule ne donne pas l'âge exact, on
    // considère la personne comme la plus jeune possible.
    return (now ?? DateTime.now()).year - year - 1 < AppConfig.digitalConsentAge;
  }

  bool get isMinor => isMinorBirthYear(birthYear);

  bool get isAssistant => role == 'assistant';

  /// Libellé complet de la catégorie : « Arbitre de ligue · R2 ».
  String get categoryLabel {
    final name = level == customCategoryId
        ? ((customCategory?.isNotEmpty ?? false) ? customCategory! : 'Autre catégorie')
        : (findCategory(country, level)?.name ?? 'Catégorie à préciser');
    return (levelDetail?.isNotEmpty ?? false) ? '$name · $levelDetail' : name;
  }

  /// Le profil est complet quand la politique de confidentialité en vigueur
  /// est acceptée et, pour un mineur, quand l'accord parental est donné.
  bool get isComplete =>
      birthYear != null &&
      privacyAcceptedAt != null &&
      privacyVersion == AppConfig.privacyVersion &&
      (!isMinor || parentalConsent);

  Profile copyWith({
    String? firstName,
    String? country,
    String? level,
    String? Function()? levelDetail,
    String? Function()? customCategory,
    String? role,
    bool? alsoOther,
    String? goal,
    int? birthYear,
    bool? parentalConsent,
    String? parentEmail,
    String? privacyAcceptedAt,
    String? privacyVersion,
    bool? largeText,
    int? xp,
    int? streak,
    String? lastActive,
  }) =>
      Profile(
        firstName: firstName ?? this.firstName,
        country: country ?? this.country,
        level: level ?? this.level,
        levelDetail: levelDetail == null ? this.levelDetail : levelDetail(),
        customCategory: customCategory == null ? this.customCategory : customCategory(),
        role: role ?? this.role,
        alsoOther: alsoOther ?? this.alsoOther,
        goal: goal ?? this.goal,
        birthYear: birthYear ?? this.birthYear,
        parentalConsent: parentalConsent ?? this.parentalConsent,
        parentEmail: parentEmail ?? this.parentEmail,
        privacyAcceptedAt: privacyAcceptedAt ?? this.privacyAcceptedAt,
        privacyVersion: privacyVersion ?? this.privacyVersion,
        largeText: largeText ?? this.largeText,
        xp: xp ?? this.xp,
        streak: streak ?? this.streak,
        lastActive: lastActive ?? this.lastActive,
      );

  /// Ligne de la table `profiles` (sans l'id, ajouté par l'appelant).
  Map<String, dynamic> toRow() => {
        'first_name': (firstName?.isEmpty ?? true) ? null : firstName,
        'country': country,
        'level': level,
        'level_detail': (levelDetail?.isEmpty ?? true) ? null : levelDetail,
        'custom_category': level == customCategoryId && (customCategory?.isNotEmpty ?? false) ? customCategory : null,
        'role': role,
        'also_other': alsoOther,
        'goal': goal,
        'birth_year': birthYear,
        'parental_consent': parentalConsent,
        'parent_email': (parentEmail?.isEmpty ?? true) ? null : parentEmail,
        'privacy_accepted_at': privacyAcceptedAt,
        'privacy_version': privacyVersion,
        'large_text': largeText,
        'xp': xp,
        'streak': streak,
        'last_active': lastActive,
      };

  factory Profile.fromRow(Map<String, dynamic> j) => Profile(
        firstName: j['first_name'] as String?,
        country: (j['country'] as String?) == 'MA' ? 'MA' : 'FR',
        level: migrateLevel((j['level'] as String?) ?? 'district'),
        levelDetail: j['level_detail'] as String?,
        customCategory: j['custom_category'] as String?,
        role: (j['role'] as String?) ?? 'central',
        alsoOther: (j['also_other'] as bool?) ?? (j['role'] == 'mixte'),
        goal: (j['goal'] as String?) ?? 'progresser',
        birthYear: (j['birth_year'] as num?)?.toInt(),
        parentalConsent: (j['parental_consent'] as bool?) ?? false,
        parentEmail: j['parent_email'] as String?,
        privacyAcceptedAt: j['privacy_accepted_at'] as String?,
        privacyVersion: j['privacy_version'] as String?,
        largeText: (j['large_text'] as bool?) ?? false,
        xp: ((j['xp'] as num?) ?? 0).toInt(),
        streak: ((j['streak'] as num?) ?? 0).toInt(),
        lastActive: j['last_active'] as String?,
      );
}

class Tally {
  const Tally([this.total = 0, this.correct = 0]);
  final int total, correct;
  Tally add(bool ok) => Tally(total + 1, correct + (ok ? 1 : 0));
  double? get ratio => total == 0 ? null : correct / total;
  int? get percent => total == 0 ? null : (100 * correct / total).round();
  Map<String, dynamic> toJson() => {'total': total, 'correct': correct};
  factory Tally.fromJson(Map<String, dynamic> j) =>
      Tally(((j['total'] as num?) ?? 0).toInt(), ((j['correct'] as num?) ?? 0).toInt());
}

class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.mode,
    required this.correct,
    required this.total,
    required this.playedOn,
    this.isExam = false,
    this.passed,
  });
  final String id, mode, playedOn;
  final int correct, total;
  final bool isExam;
  final bool? passed;

  Map<String, dynamic> toRow() => {
        'id': id,
        'mode': mode,
        'correct': correct,
        'total': total,
        'is_exam': isExam,
        'passed': passed,
        'played_on': playedOn,
      };

  factory SessionRecord.fromRow(Map<String, dynamic> j) => SessionRecord(
        id: j['id'] as String,
        mode: j['mode'] as String,
        correct: (j['correct'] as num).toInt(),
        total: (j['total'] as num).toInt(),
        isExam: (j['is_exam'] as bool?) ?? false,
        passed: j['passed'] as bool?,
        playedOn: j['played_on'] as String,
      );
}

/// Un match du carnet : prévu (désignation à venir) ou joué (débriefé).
class MatchEntry {
  const MatchEntry({
    required this.id,
    required this.playedOn,
    required this.competition,
    required this.role,
    this.status = 'joue',
    this.teams,
    this.goal,
    this.goalResult,
    this.satisfaction,
    this.feeling,
    this.workPoints = const [],
    this.nextGoal,
    this.yellowCards = 0,
    this.redCards = 0,
    this.observerNote,
    this.improvement,
    this.evals = const {},
  });
  final String id, playedOn, competition, role;
  final String status; // prevu | joue
  final String? teams;
  final String? goal; // objectif fixé pour ce match
  final String? goalResult; // atteint | en_partie | non_atteint
  final int? satisfaction; // 1 à 5
  final String? feeling; // ressenti
  final List<String> workPoints;
  final String? nextGoal; // objectif pour le match suivant
  final int yellowCards, redCards;
  final double? observerNote;
  final String? improvement;
  final Map<String, int> evals;

  bool get planned => status == 'prevu';

  int eval(String key) => evals[key] ?? 3;

  static String? _opt(String? s) => (s?.trim().isEmpty ?? true) ? null : s!.trim();

  MatchEntry copyWith({
    String? playedOn,
    String? competition,
    String? role,
    String? status,
    String? Function()? teams,
    String? Function()? goal,
    String? Function()? goalResult,
    int? Function()? satisfaction,
    String? Function()? feeling,
    List<String>? workPoints,
    String? Function()? nextGoal,
    int? yellowCards,
    int? redCards,
    double? Function()? observerNote,
    String? Function()? improvement,
    Map<String, int>? evals,
  }) =>
      MatchEntry(
        id: id,
        playedOn: playedOn ?? this.playedOn,
        competition: competition ?? this.competition,
        role: role ?? this.role,
        status: status ?? this.status,
        teams: teams == null ? this.teams : teams(),
        goal: goal == null ? this.goal : goal(),
        goalResult: goalResult == null ? this.goalResult : goalResult(),
        satisfaction: satisfaction == null ? this.satisfaction : satisfaction(),
        feeling: feeling == null ? this.feeling : feeling(),
        workPoints: workPoints ?? this.workPoints,
        nextGoal: nextGoal == null ? this.nextGoal : nextGoal(),
        yellowCards: yellowCards ?? this.yellowCards,
        redCards: redCards ?? this.redCards,
        observerNote: observerNote == null ? this.observerNote : observerNote(),
        improvement: improvement == null ? this.improvement : improvement(),
        evals: evals ?? this.evals,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'played_on': playedOn,
        'competition': competition,
        'role': role,
        'status': status,
        'teams': _opt(teams),
        'goal': _opt(goal),
        'goal_result': goalResult,
        'satisfaction': satisfaction,
        'feeling': _opt(feeling),
        'work_points': workPoints,
        'next_goal': _opt(nextGoal),
        'yellow_cards': yellowCards,
        'red_cards': redCards,
        'observer_note': observerNote,
        'improvement': _opt(improvement),
        for (final (k, _) in evalCriteria) 'eval_$k': eval(k),
      };

  factory MatchEntry.fromRow(Map<String, dynamic> j) => MatchEntry(
        id: j['id'] as String,
        playedOn: j['played_on'] as String,
        competition: j['competition'] as String,
        role: j['role'] as String,
        status: (j['status'] as String?) ?? 'joue',
        teams: j['teams'] as String?,
        goal: j['goal'] as String?,
        goalResult: j['goal_result'] as String?,
        satisfaction: (j['satisfaction'] as num?)?.toInt(),
        feeling: j['feeling'] as String?,
        workPoints: [for (final w in (j['work_points'] as List? ?? const [])) w.toString()],
        nextGoal: j['next_goal'] as String?,
        yellowCards: ((j['yellow_cards'] as num?) ?? 0).toInt(),
        redCards: ((j['red_cards'] as num?) ?? 0).toInt(),
        observerNote: (j['observer_note'] as num?)?.toDouble(),
        improvement: j['improvement'] as String?,
        evals: {
          for (final (k, _) in evalCriteria)
            if (j['eval_$k'] != null) k: (j['eval_$k'] as num).toInt(),
        },
      );
}

/// Résultat d'un test physique saisi par l'arbitre.
class PhysicalResult {
  const PhysicalResult({required this.id, required this.test, required this.value, required this.doneOn, this.passed});
  final String id, test, value, doneOn; // value : « 4,88 » (secondes) ou « 15-3 » (palier)
  final bool? passed;

  Map<String, dynamic> toRow() => {'id': id, 'test': test, 'value': value, 'done_on': doneOn, 'passed': passed};

  factory PhysicalResult.fromRow(Map<String, dynamic> j) => PhysicalResult(
        id: j['id'] as String,
        test: j['test'] as String,
        value: j['value'] as String,
        doneOn: j['done_on'] as String,
        passed: j['passed'] as bool?,
      );
}

/// Toutes les données d'un utilisateur, telles que gardées sur l'appareil.
class UserData {
  UserData({
    this.profile = const Profile(),
    Map<int, Tally>? laws,
    this.offside = const Tally(),
    Map<String, ReviewEntry>? reviews,
    List<SessionRecord>? sessions,
    List<MatchEntry>? matches,
    Set<String>? badges,
    Map<int, String>? readLessons,
    List<PhysicalResult>? physical,
    List<CategorySuggestion>? suggestions,
  })  : laws = laws ?? {},
        physical = physical ?? [],
        suggestions = suggestions ?? [],
        reviews = reviews ?? {},
        sessions = sessions ?? [],
        matches = matches ?? [],
        badges = badges ?? {},
        readLessons = readLessons ?? {};

  Profile profile;
  final Map<int, Tally> laws;
  Tally offside;
  final Map<String, ReviewEntry> reviews;
  final List<SessionRecord> sessions; // de la plus ancienne à la plus récente
  final List<MatchEntry> matches; // de la plus récente à la plus ancienne
  final Set<String> badges;
  final Map<int, String> readLessons; // loi -> date de lecture
  final List<PhysicalResult> physical; // du plus récent au plus ancien
  final List<CategorySuggestion> suggestions; // propositions de l'utilisateur

  static const maxSessions = 300;

  Tally law(int l) => laws[l] ?? const Tally();

  void sortMatches() => matches.sort((a, b) => b.playedOn.compareTo(a.playedOn));

  /// Matchs prévus, du plus proche au plus lointain.
  List<MatchEntry> get plannedMatches => matches.where((m) => m.planned).toList().reversed.toList();

  /// Matchs joués, du plus récent au plus ancien.
  List<MatchEntry> get playedMatches => matches.where((m) => !m.planned).toList();

  Map<String, dynamic> toJson() => {
        'v': 1,
        'profile': profile.toRow(),
        'laws': {for (final e in laws.entries) '${e.key}': e.value.toJson()},
        'offside': offside.toJson(),
        'reviews': {for (final e in reviews.entries) e.key: e.value.toJson()},
        'sessions': [for (final s in sessions) s.toRow()],
        'matches': [for (final m in matches) m.toRow()],
        'badges': badges.toList(),
        'read': {for (final e in readLessons.entries) '${e.key}': e.value},
        'physical': [for (final p in physical) p.toRow()],
        'suggestions': [for (final x in suggestions) x.toJson()],
      };

  factory UserData.fromJson(Map<String, dynamic> j) => UserData(
        profile: Profile.fromRow(Map<String, dynamic>.from(j['profile'] as Map? ?? {})),
        laws: {
          for (final e in (j['laws'] as Map? ?? {}).entries)
            int.parse(e.key as String): Tally.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        offside: Tally.fromJson(Map<String, dynamic>.from(j['offside'] as Map? ?? {})),
        reviews: {
          for (final e in (j['reviews'] as Map? ?? {}).entries)
            e.key as String: ReviewEntry.fromJson(Map<String, dynamic>.from(e.value as Map)),
        },
        sessions: [
          for (final s in (j['sessions'] as List? ?? [])) SessionRecord.fromRow(Map<String, dynamic>.from(s as Map)),
        ],
        matches: [
          for (final m in (j['matches'] as List? ?? [])) MatchEntry.fromRow(Map<String, dynamic>.from(m as Map)),
        ],
        badges: {for (final b in (j['badges'] as List? ?? [])) b as String},
        readLessons: {
          for (final e in (j['read'] as Map? ?? {}).entries) int.parse(e.key as String): e.value as String,
        },
        physical: [
          for (final p in (j['physical'] as List? ?? [])) PhysicalResult.fromRow(Map<String, dynamic>.from(p as Map)),
        ],
        suggestions: [
          for (final x in (j['suggestions'] as List? ?? []))
            CategorySuggestion.fromRow(Map<String, dynamic>.from(x as Map)),
        ],
      );

  bool didToday(String mode) {
    final t = todayIso();
    return sessions.any((s) => s.playedOn == t && s.mode == mode);
  }
}
