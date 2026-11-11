import '../config.dart';
import '../logic/dates.dart';
import '../logic/srs.dart';

const profileLevels = <String, String>{
  'jeune': 'Jeune arbitre / débutant',
  'district': 'Arbitre de district ou de ligue',
  'federal': 'Arbitre régional ou fédéral',
  'formateur': 'Formateur ou observateur',
};
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
];

class Profile {
  const Profile({
    this.firstName,
    this.level = 'district',
    this.role = 'central',
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
  final String level, role, goal;
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

  /// Le profil est complet quand la politique de confidentialité en vigueur
  /// est acceptée et, pour un mineur, quand l'accord parental est donné.
  bool get isComplete =>
      birthYear != null &&
      privacyAcceptedAt != null &&
      privacyVersion == AppConfig.privacyVersion &&
      (!isMinor || parentalConsent);

  Profile copyWith({
    String? firstName,
    String? level,
    String? role,
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
        level: level ?? this.level,
        role: role ?? this.role,
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
        'level': level,
        'role': role,
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
        level: (j['level'] as String?) ?? 'district',
        role: (j['role'] as String?) ?? 'central',
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

class MatchEntry {
  const MatchEntry({
    required this.id,
    required this.playedOn,
    required this.competition,
    required this.role,
    this.observerNote,
    this.improvement,
    this.evals = const {},
  });
  final String id, playedOn, competition, role;
  final double? observerNote;
  final String? improvement;
  final Map<String, int> evals;

  int eval(String key) => evals[key] ?? 3;

  Map<String, dynamic> toRow() => {
        'id': id,
        'played_on': playedOn,
        'competition': competition,
        'role': role,
        'observer_note': observerNote,
        'improvement': (improvement?.isEmpty ?? true) ? null : improvement,
        for (final (k, _) in evalCriteria) 'eval_$k': eval(k),
      };

  factory MatchEntry.fromRow(Map<String, dynamic> j) => MatchEntry(
        id: j['id'] as String,
        playedOn: j['played_on'] as String,
        competition: j['competition'] as String,
        role: j['role'] as String,
        observerNote: (j['observer_note'] as num?)?.toDouble(),
        improvement: j['improvement'] as String?,
        evals: {
          for (final (k, _) in evalCriteria)
            if (j['eval_$k'] != null) k: (j['eval_$k'] as num).toInt(),
        },
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
  })  : laws = laws ?? {},
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

  static const maxSessions = 300;

  Tally law(int l) => laws[l] ?? const Tally();

  void sortMatches() => matches.sort((a, b) => b.playedOn.compareTo(a.playedOn));

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
      );

  bool didToday(String mode) {
    final t = todayIso();
    return sessions.any((s) => s.playedOn == t && s.mode == mode);
  }
}
