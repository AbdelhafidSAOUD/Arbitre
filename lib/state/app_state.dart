import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config.dart';
import '../data/content_repository.dart';
import '../data/local_store.dart';
import '../data/remote.dart';
import '../data/sync.dart';
import '../logic/categories.dart';
import '../logic/dates.dart';
import '../logic/offside.dart';
import '../logic/progress.dart';
import '../logic/quiz.dart';
import '../logic/selection.dart';
import '../logic/srs.dart';
import '../models/content.dart';
import '../models/user_data.dart';

class DailyTask {
  const DailyTask(this.kind, this.label, this.subtitle, this.done, {this.law});
  final String kind; // review | daily | lesson | exam | offside
  final String label, subtitle;
  final bool done;
  final int? law;
}

/// État central de l'application.
///
/// Règle d'or : toute modification est appliquée immédiatement sur
/// l'appareil (l'interface ne dépend jamais du réseau), puis mise en file
/// pour le serveur.
class AppState extends ChangeNotifier {
  AppState({required this.store, required this.content, this.remote, Random? random})
      : rng = random ?? Random();

  final LocalStore store;
  final ContentRepository content;
  final Remote? remote;
  final Random rng;
  static const _uuid = Uuid();
  static const localUserId = 'local';

  String? _uid;
  UserData _data = UserData();
  List<SyncOp> _queue = [];
  bool ready = false;
  bool syncing = false;
  /// Catégories et niveaux ajoutés par des arbitres et validés.
  List<CategorySuggestion> sharedSuggestions = [];
  String? syncError;
  DateTime? lastSyncAt;
  StreamSubscription<String?>? _authSub;
  Timer? _syncTimer, _debounce;

  bool get isLocalMode => remote == null;
  bool get isSignedIn => _uid != null;
  String? get email => remote?.email;
  UserData get data => _data;
  Profile get profile => _data.profile;
  bool get needsOnboarding => !profile.isComplete;
  int get pendingChanges => _queue.length;
  LevelInfo get level => levelFor(profile.xp);

  // ================================================================ Démarrage

  Future<void> init() async {
    await content.load();
    sharedSuggestions = store.loadSharedSuggestions();
    final r = remote;
    if (r == null) {
      await _openUser(localUserId);
    } else {
      final uid = r.userId;
      if (uid != null) await _openUser(uid);
      _authSub = r.userChanges.listen((uid) {
        if (uid == null) {
          if (_uid != null) _closeUser();
        } else if (uid != _uid) {
          _openUser(uid);
        }
      });
      _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) => sync());
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _openUser(String uid) async {
    _uid = uid;
    _data = store.loadUserData(uid) ?? UserData();
    _queue = store.loadQueue(uid);
    notifyListeners();
    if (remote != null) unawaited(sync(pull: true));
  }

  void _closeUser() {
    _uid = null;
    _data = UserData();
    _queue = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _syncTimer?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // ========================================================= Synchronisation

  void _enqueue(SyncOp op) {
    if (remote == null) return;
    _queue.add(op);
  }

  Future<void> _persist() async {
    final uid = _uid;
    if (uid == null) return;
    await store.saveUserData(uid, _data);
    if (remote != null) {
      await store.saveQueue(uid, _queue);
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 3), () => sync());
    }
  }

  /// Envoie les écritures en attente, puis (si [pull]) récupère les données
  /// du serveur. Ne lève jamais d'exception : en cas d'échec, les données
  /// restent dans la file et un nouvel essai a lieu plus tard.
  Future<void> sync({bool pull = false}) async {
    final r = remote;
    final uid = _uid;
    if (r == null || uid == null || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      for (final batch in batchOps(List.of(_queue))) {
        try {
          await r.applyBatch(batch);
        } on PermanentSyncError catch (e) {
          debugPrint('Écriture abandonnée : $e');
        }
        if (_uid != uid) return; // déconnecté pendant l'envoi
        _queue.removeRange(0, batch.length);
        await store.saveQueue(uid, _queue);
      }
      if (pull && _queue.isEmpty) {
        final fresh = await r.fetchContent();
        await content.replace(fresh.questions, fresh.lessons);
        sharedSuggestions = fresh.suggestions;
        await store.saveSharedSuggestions(sharedSuggestions);
        final remoteData = await r.fetchUserData(uid);
        if (_uid != uid) return;
        if (remoteData != null) {
          remoteData.readLessons.addAll(_data.readLessons);
          _data = remoteData;
          await store.saveUserData(uid, _data);
        } else if (_data.profile.isComplete) {
          // Profil créé hors ligne, pas encore sur le serveur.
          _enqueueProfile();
          await store.saveQueue(uid, _queue);
        }
      }
      syncError = null;
      lastSyncAt = DateTime.now();
    } catch (e) {
      debugPrint('Synchronisation reportée : $e');
      syncError = 'Synchronisation en attente : vérifiez votre connexion.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _enqueueProfile() {
    final uid = _uid;
    if (uid == null) return;
    _enqueue(SyncOp.upsert('profiles', {'id': uid, ...profile.toRow()}));
  }

  // ================================================================= Comptes

  Future<void> sendCode(String email) => remote!.sendCode(email.trim());

  Future<void> verifyCode(String email, String code) => remote!.verifyCode(email.trim(), code.trim());

  Future<void> signInWithPassword(String email, String password) =>
      remote!.signInWithPassword(email.trim(), password);

  /// Déconnexion. Renvoie false si des données n'ont pas pu être envoyées
  /// (l'appelant peut alors demander confirmation et forcer).
  Future<bool> signOut({bool force = false}) async {
    final r = remote;
    final uid = _uid;
    if (r == null || uid == null) return true;
    await sync();
    if (_queue.isNotEmpty && !force) return false;
    try {
      await r.signOut();
    } catch (e) {
      debugPrint('Déconnexion serveur impossible : $e');
    }
    await store.deleteUser(uid);
    _closeUser();
    return true;
  }

  /// Suppression définitive du compte et de toutes les données.
  Future<void> deleteAccount() async {
    final uid = _uid;
    if (uid == null) return;
    if (remote != null) {
      await remote!.deleteAccount();
      try {
        await remote!.signOut();
      } catch (_) {
        // Le compte n'existe plus : la session locale est de toute façon effacée.
      }
      await store.deleteUser(uid);
      _closeUser();
    } else {
      await store.deleteUser(uid);
      _data = UserData();
      _queue = [];
      notifyListeners();
    }
  }

  /// Copie lisible de toutes les données personnelles (droit d'accès et
  /// de portabilité du RGPD).
  String exportData() => const JsonEncoder.withIndent('  ').convert({
        'exporte_le': DateTime.now().toIso8601String(),
        'compte': email,
        'donnees': _data.toJson(),
      });

  // ================================================================== Profil

  Future<void> saveProfile(Profile p) async {
    _data.profile = p;
    _enqueueProfile();
    notifyListeners();
    await _persist();
  }

  Future<void> acceptPrivacyAndSave(Profile p) => saveProfile(p.copyWith(
        privacyAcceptedAt: DateTime.now().toUtc().toIso8601String(),
        privacyVersion: AppConfig.privacyVersion,
      ));

  // =============================================================== Requêtes

  int? lawPercent(int law) => _data.law(law).percent;

  List<int> weakLaws(int n) {
    final laws = List.generate(17, (i) => i + 1)
      ..sort((a, b) {
        final pa = _data.law(a).ratio ?? -1;
        final pb = _data.law(b).ratio ?? -1;
        return pa != pb ? pa.compareTo(pb) : a.compareTo(b);
      });
    return laws.take(n).toList();
  }

  List<String> dueQuestionIds() {
    final ids = _data.reviews.entries
        .where((e) => isDue(e.value) && content.byId(e.key) != null)
        .toList()
      ..sort((a, b) => a.value.due.compareTo(b.value.due));
    return ids.map((e) => e.key).toList();
  }

  List<DailyTask> dailyProgram() {
    final due = dueQuestionIds().length;
    final weak = weakLaws(1).first;
    final today = todayIso();
    final tasks = <DailyTask>[
      due > 0
          ? DailyTask('review', 'Revoir vos $due erreur${due > 1 ? 's' : ''} programmée${due > 1 ? 's' : ''}',
              'Révisions espacées', _data.didToday(Labels.review))
          : DailyTask('daily', 'Défi du jour', '5 questions sur vos lois fragiles', _data.didToday(Labels.daily)),
      DailyTask('lesson', 'Relire la loi $weak : ${lawName(weak)}', 'Fiche de 2 minutes',
          _data.readLessons[weak] == today,
          law: weak),
    ];
    final offside = DailyTask('offside', '10 situations de hors-jeu', 'Simulateur', _data.didToday(Labels.offside));
    if (profile.goal == 'examen') {
      tasks.add(DailyTask('exam', 'Examen blanc',
          '${AppConfig.examQuestions} questions · ${AppConfig.examMinutes} minutes', _data.didToday(Labels.exam)));
      if (profile.role != 'central') tasks.add(offside);
    } else {
      tasks.add(offside);
    }
    return tasks;
  }

  // ================================================================ Séances

  QuizConfig configFor(String kind, {int? law}) => switch (kind) {
        'quick' => const QuizConfig(label: Labels.quick, count: 10, offsideCount: 2),
        'match' => const QuizConfig(label: Labels.match, count: 10, offsideCount: 2, timed: true),
        'offside' => const QuizConfig(label: Labels.offside, count: 10, offsideOnly: true),
        'exam' => const QuizConfig(
            label: Labels.exam, count: AppConfig.examQuestions, offsideCount: 3, exam: true),
        'daily' => QuizConfig(label: Labels.daily, count: 5, laws: [...weakLaws(5), 11, 12]),
        'weak' => QuizConfig(label: Labels.weak, count: 8, laws: [...weakLaws(3), 12]),
        'review' => QuizConfig(
            label: Labels.review, count: min(15, dueQuestionIds().length), questionIds: dueQuestionIds()),
        'classroom' => const QuizConfig(label: Labels.classroom, count: 9, offsideCount: 1, classroom: true),
        'law' => QuizConfig(
            label: 'Loi $law · ${lawName(law!)}', count: 10, offsideCount: law == 11 ? 3 : 0, laws: [law]),
        _ => throw ArgumentError(kind),
      };

  List<QuizItem> buildQuiz(QuizConfig c) {
    List<Question> picked;
    if (c.offsideOnly) {
      picked = [for (var i = 0; i < c.count; i++) offsideQuestion(generateOffside(rng))];
    } else {
      var pool = content.questions.where((q) => c.laws == null || c.laws!.contains(q.law)).toList();
      if (c.questionIds != null) {
        final ids = c.questionIds!.toSet();
        pool = content.questions.where((q) => ids.contains(q.id)).toList();
      }
      picked = weightedSample<Question>(
        pool,
        max(0, c.count - c.offsideCount),
        (q) => questionWeight(q, level: profile.level, role: profile.role, lawAccuracy: _data.law(q.law).ratio),
        rng,
      );
      for (var i = 0; i < c.offsideCount; i++) {
        picked.insert(rng.nextInt(picked.length + 1), offsideQuestion(generateOffside(rng)));
      }
    }
    return [
      for (final q in picked) QuizItem(q, List.generate(q.options.length, (i) => i)..shuffle(rng)),
    ];
  }

  /// Enregistre une réponse (statistiques, révisions espacées, journal).
  void recordAnswer(Question q, bool correct, String mode) {
    _data.laws[q.law] = _data.law(q.law).add(correct);
    if (q.isOffside) {
      _data.offside = _data.offside.add(correct);
    } else {
      final res = updateReview(_data.reviews[q.id], correct);
      if (res.changed) {
        if (res.entry == null) {
          _data.reviews.remove(q.id);
          _enqueue(SyncOp.delete('reviews', {'question_id': q.id}));
        } else {
          _data.reviews[q.id] = res.entry!;
          _enqueue(SyncOp.upsert(
            'reviews',
            {'question_id': q.id, 'box': res.entry!.box, 'due': res.entry!.due},
            onConflict: 'user_id,question_id',
          ));
        }
      }
    }
    _enqueue(SyncOp.upsert(
      'answers',
      {
        'id': _uuid.v4(),
        'question_id': q.isOffside ? null : q.id,
        'law': q.law,
        'correct': correct,
        'mode': mode,
        'answered_at': DateTime.now().toUtc().toIso8601String(),
      },
      ignoreDuplicates: true,
    ));
    notifyListeners();
    _persist();
  }

  /// Clôture une séance : XP, série de jours, badges.
  SessionOutcome completeSession(QuizConfig c, List<QuizItem> items) {
    if (c.exam) {
      for (final it in items) {
        recordAnswer(it.question, it.correct, c.label);
      }
    }
    final correct = items.where((i) => i.correct).length;
    final total = items.length;
    final passed = c.exam ? correct / total >= AppConfig.examPassRatio : null;
    return _closeSession(c.label, correct, total, timed: c.timed, exam: c.exam, passed: passed);
  }

  /// Séance notée hors quiz (format examen, rapport disciplinaire) :
  /// [correct] sur [total] points.
  SessionOutcome recordScoredSession(String label, int correct, int total) =>
      _closeSession(label, correct, total);

  SessionOutcome _closeSession(String label, int correct, int total,
      {bool timed = false, bool exam = false, bool? passed}) {
    final xp = sessionXp(correct: correct, total: total, timed: timed, examPassed: passed ?? false);
    final today = todayIso();
    _data.profile = profile.copyWith(
      xp: profile.xp + xp,
      streak: nextStreak(
        streak: profile.streak,
        lastActive: profile.lastActive,
        today: today,
        yesterday: addDaysIso(-1),
      ),
      lastActive: today,
    );
    final session = SessionRecord(
      id: _uuid.v4(),
      mode: label,
      correct: correct,
      total: total,
      isExam: exam,
      passed: passed,
      playedOn: today,
    );
    _data.sessions.add(session);
    if (_data.sessions.length > UserData.maxSessions) _data.sessions.removeAt(0);
    final fresh = awardBadges(_data);
    _enqueueProfile();
    _enqueue(SyncOp.upsert('sessions', session.toRow(), ignoreDuplicates: true));
    for (final b in fresh) {
      _enqueue(SyncOp.upsert('badges', {'badge_id': b.id}, onConflict: 'user_id,badge_id', ignoreDuplicates: true));
    }
    notifyListeners();
    _persist();
    return SessionOutcome(
      correct: correct,
      total: total,
      xp: xp,
      totalXp: profile.xp,
      newBadges: fresh,
      exam: exam,
      passed: passed,
    );
  }

  // ======================================================= Formation, matchs

  void markLessonRead(int law) {
    _data.readLessons[law] = todayIso();
    notifyListeners();
    _persist();
  }

  String newId() => _uuid.v4();

  List<BadgeDef> saveMatch(MatchEntry m) {
    _data.matches.removeWhere((x) => x.id == m.id);
    _data.matches.add(m);
    _data.sortMatches();
    final fresh = awardBadges(_data);
    _enqueue(SyncOp.upsert('matches', m.toRow()));
    for (final b in fresh) {
      _enqueue(SyncOp.upsert('badges', {'badge_id': b.id}, onConflict: 'user_id,badge_id', ignoreDuplicates: true));
    }
    notifyListeners();
    _persist();
    return fresh;
  }

  // ============================================= Catégories proposées

  /// Propositions visibles : validées (tous les arbitres) et les siennes.
  List<CategorySuggestion> get allSuggestions => [...sharedSuggestions, ..._data.suggestions];

  /// Enregistre la proposition d'une catégorie ou d'un niveau. Elle sera
  /// visible des autres arbitres une fois validée.
  void proposeCategory({required String country, required String kind, required String label, String? categoryId}) {
    final clean = cleanLabel(label);
    if (clean.isEmpty) return;
    final exists = allSuggestions.any((x) =>
        x.country == country && x.kind == kind && x.categoryId == categoryId && x.label.toLowerCase() == clean.toLowerCase());
    if (exists) return;
    final sugg = CategorySuggestion(id: _uuid.v4(), country: country, kind: kind, label: clean, categoryId: categoryId);
    _data.suggestions.add(sugg);
    _enqueue(SyncOp.upsert('category_suggestions', sugg.toRow(), ignoreDuplicates: true));
    notifyListeners();
    _persist();
  }

  // ======================================================= Tests physiques

  void savePhysical(PhysicalResult r) {
    _data.physical
      ..removeWhere((x) => x.id == r.id)
      ..insert(0, r)
      ..sort((a, b) => b.doneOn.compareTo(a.doneOn));
    _enqueue(SyncOp.upsert('physical_results', r.toRow()));
    notifyListeners();
    _persist();
  }

  void deletePhysical(String id) {
    _data.physical.removeWhere((x) => x.id == id);
    _enqueue(SyncOp.delete('physical_results', {'id': id}));
    notifyListeners();
    _persist();
  }

  // ================================================ Brouillons de rapports

  /// Brouillon gardé sur l'appareil uniquement (jamais envoyé au serveur).
  String reportDraft(String caseId) => _uid == null ? '' : store.loadDraft(_uid!, caseId);

  Future<void> saveReportDraft(String caseId, String text) async {
    if (_uid == null) return;
    await store.saveDraft(_uid!, caseId, text);
  }

  void deleteMatch(String id) {
    _data.matches.removeWhere((x) => x.id == id);
    _enqueue(SyncOp.delete('matches', {'id': id}));
    notifyListeners();
    _persist();
  }
}

/// Noms des séances (aussi utilisés pour savoir si une tâche du jour est faite).
abstract final class Labels {
  static const quick = 'Quiz rapide';
  static const match = 'Mode match';
  static const offside = 'Simulateur hors-jeu';
  static const exam = 'Examen blanc';
  static const daily = 'Défi du jour';
  static const weak = 'Révision ciblée';
  static const review = 'Révisions espacées';
  static const classroom = 'Séance en salle';
  static const examCases = 'Format examen';
  static const report = 'Rapport disciplinaire';
}
