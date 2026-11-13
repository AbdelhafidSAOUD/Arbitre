import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sifflet_academie/data/sync.dart';
import 'package:sifflet_academie/logic/categories.dart';
import 'package:sifflet_academie/logic/dates.dart';
import 'package:sifflet_academie/logic/exam_case.dart';
import 'package:sifflet_academie/logic/offside.dart';
import 'package:sifflet_academie/logic/physical.dart';
import 'package:sifflet_academie/logic/progress.dart';
import 'package:sifflet_academie/logic/report.dart';
import 'package:sifflet_academie/logic/selection.dart';
import 'package:sifflet_academie/logic/srs.dart';
import 'package:sifflet_academie/models/content.dart';
import 'package:sifflet_academie/models/user_data.dart';

void main() {
  group('Simulateur de hors-jeu', () {
    test('la réponse attendue respecte la Loi 11 sur 5 000 situations', () {
      final rng = Random(42);
      var offside = 0, behindBall = 0;
      for (var i = 0; i < 5000; i++) {
        final s = generateOffside(rng);
        final expected = s.target.y < halfwayY && s.target.y < s.secondLastY && s.target.y < s.ball.y;
        expect(s.isOffside, expected);
        // Le type tiré correspond bien au verdict.
        expect(s.isOffside, s.type == OffsideType.offside, reason: 'type ${s.type}');
        // Pas de cas litigieux : au moins 1,5 m d'écart avec la ligne de référence.
        expect((s.target.y - s.secondLastY).abs(), greaterThanOrEqualTo(1.5 - 1e-9));
        // Tout le monde est sur le terrain.
        for (final p in [...s.defenders, s.passer, s.target, ...s.decoys]) {
          expect(p.x, inInclusiveRange(0, pitchWidth));
          expect(p.y, inInclusiveRange(0, halfwayY));
        }
        if (s.isOffside) offside++;
        if (s.type == OffsideType.behindBall) behindBall++;
        final q = offsideQuestion(s);
        expect(q.options[q.answerIndex], s.isOffside ? startsWith('Oui') : startsWith('Non'));
        expect(s.explanation, isNotEmpty);
      }
      // Répartition équilibrée (environ 40 % de positions de hors-jeu).
      expect(offside, inInclusiveRange(1700, 2300));
      expect(behindBall, greaterThan(700));
    });
  });

  group('Révisions espacées', () {
    final now = DateTime(2026, 11, 11);
    test('une erreur programme une révision le lendemain', () {
      final r = updateReview(null, false, now);
      expect(r.changed, isTrue);
      expect(r.entry!.box, 1);
      expect(r.entry!.due, '2026-11-12');
    });
    test('une bonne réponse sans fiche ne crée rien', () {
      final r = updateReview(null, true, now);
      expect(r.changed, isFalse);
      expect(r.entry, isNull);
    });
    test('les intervalles s’allongent puis la question est acquise', () {
      var e = updateReview(null, false, now).entry;
      final dues = <String>[];
      for (var i = 0; i < 4; i++) {
        e = updateReview(e, true, now).entry;
        dues.add(e!.due);
      }
      expect(dues, ['2026-11-13', '2026-11-15', '2026-11-19', '2026-11-27']);
      final last = updateReview(e, true, now);
      expect(last.changed, isTrue);
      expect(last.entry, isNull);
    });
    test('une erreur renvoie en boîte 1', () {
      final r = updateReview(const ReviewEntry(box: 4, due: '2026-11-11'), false, now);
      expect(r.entry!.box, 1);
    });
  });

  group('Sélection adaptative', () {
    Question q(int d, {String? role}) => Question(
          id: 'q$d$role',
          law: 1,
          kind: 'connaissance',
          difficulty: d,
          roleTag: role,
          text: 't',
          options: const ['a', 'b'],
          answerIndex: 0,
          explanation: '',
        );
    test('un débutant reçoit surtout des questions faciles', () {
      expect(questionWeight(q(1), level: 'jad', role: 'central'),
          greaterThan(questionWeight(q(3), level: 'jad', role: 'central')));
      expect(questionWeight(q(3), level: 'federal', role: 'central'),
          greaterThan(questionWeight(q(1), level: 'federal', role: 'central')));
    });
    test('un assistant voit plus de questions d’assistant', () {
      expect(questionWeight(q(1, role: 'assistant'), level: 'district', role: 'assistant'), 2);
      expect(questionWeight(q(1, role: 'assistant'), level: 'district', role: 'central'), 1);
    });
    test('le tirage renvoie n éléments distincts', () {
      final pool = List.generate(50, (i) => i);
      final s = weightedSample<int>(pool, 10, (i) => 1.0 + i, Random(1));
      expect(s.length, 10);
      expect(s.toSet().length, 10);
      expect(weightedSample<int>(pool, 80, (_) => 1, Random(1)).length, 50);
    });
  });

  group('Progression', () {
    test('niveaux', () {
      // Paliers neutres : ils ne doivent pas ressembler à une catégorie officielle.
      expect(levelFor(0).name, 'Palier 1');
      expect(levelFor(640).name, 'Palier 2');
      expect(levelFor(640).next, 800);
      expect(levelFor(9999).next, isNull);
    });
    test('série de jours', () {
      expect(nextStreak(streak: 4, lastActive: '2026-11-10', today: '2026-11-11', yesterday: '2026-11-10'), 5);
      expect(nextStreak(streak: 4, lastActive: '2026-11-11', today: '2026-11-11', yesterday: '2026-11-10'), 4);
      expect(nextStreak(streak: 4, lastActive: '2026-11-01', today: '2026-11-11', yesterday: '2026-11-10'), 1);
      expect(nextStreak(streak: 0, lastActive: null, today: '2026-11-11', yesterday: '2026-11-10'), 1);
    });
    test('XP', () {
      expect(sessionXp(correct: 7, total: 10), 70);
      expect(sessionXp(correct: 10, total: 10, timed: true), 170);
      expect(sessionXp(correct: 25, total: 30, examPassed: true), 350);
    });
    test('accord parental sous 15 ans', () {
      final now = DateTime(2026, 11, 11);
      expect(Profile.isMinorBirthYear(2013, now), isTrue);
      expect(Profile.isMinorBirthYear(2011, now), isTrue); // 14 ou 15 ans : prudence
      expect(Profile.isMinorBirthYear(2010, now), isFalse);
      expect(Profile.isMinorBirthYear(null, now), isFalse);
    });
  });

  group('Synchronisation', () {
    test('les écritures consécutives sont regroupées sans changer l’ordre', () {
      final ops = [
        const SyncOp.upsert('answers', {'id': '1'}, ignoreDuplicates: true),
        const SyncOp.upsert('answers', {'id': '2'}, ignoreDuplicates: true),
        const SyncOp.upsert('reviews', {'question_id': 'a', 'box': 1}, onConflict: 'user_id,question_id'),
        const SyncOp.delete('reviews', {'question_id': 'a'}),
        const SyncOp.upsert('answers', {'id': '3'}, ignoreDuplicates: true),
      ];
      final b = batchOps(ops);
      expect(b.map((x) => x.length).toList(), [2, 1, 1, 1]);
      expect(b.expand((x) => x).toList(), ops);
    });
    test('une même ligne n’est envoyée qu’une fois par lot (dernière version)', () {
      final rows = dedupeRows(const [
        SyncOp.upsert('profiles', {'id': 'u', 'xp': 10}),
        SyncOp.upsert('profiles', {'id': 'u', 'xp': 30}),
      ]);
      expect(rows, [
        {'id': 'u', 'xp': 30},
      ]);
    });
    test('la file survit à une sérialisation', () {
      const op = SyncOp.upsert('reviews', {'question_id': 'x', 'box': 2, 'due': '2026-11-13'}, onConflict: 'user_id,question_id');
      final back = SyncOp.fromJson(jsonDecode(jsonEncode(op.toJson())) as Map<String, dynamic>);
      expect(back.table, 'reviews');
      expect(back.onConflict, 'user_id,question_id');
      expect(back.data['box'], 2);
    });
  });

  group('Données', () {
    test('aller-retour JSON des données utilisateur', () {
      final d = UserData(
        profile: const Profile(firstName: 'Sam', xp: 120, birthYear: 1995),
        laws: {11: const Tally(10, 7)},
        offside: const Tally(5, 4),
        reviews: {'L11-x': const ReviewEntry(box: 2, due: '2026-11-13')},
        sessions: [const SessionRecord(id: 's', mode: 'Quiz rapide', correct: 7, total: 10, playedOn: '2026-11-11')],
        matches: [const MatchEntry(id: 'm', playedOn: '2026-11-08', competition: 'U17', role: 'Arbitre central', observerNote: 14.5, evals: {'placement': 4})],
        badges: {'first'},
        readLessons: {11: '2026-11-11'},
      );
      final back = UserData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(back.profile.firstName, 'Sam');
      expect(back.law(11).correct, 7);
      expect(back.offside.total, 5);
      expect(back.reviews['L11-x']!.box, 2);
      expect(back.matches.single.observerNote, 14.5);
      expect(back.matches.single.eval('placement'), 4);
      expect(back.matches.single.eval('laws'), 3);
      expect(back.badges, {'first'});
      expect(back.readLessons[11], '2026-11-11');
    });
    test('aller-retour JSON des nouveautés : profil détaillé, débriefing, physique', () {
      final d = UserData(
        profile: const Profile(country: 'MA', level: 'autre', customCategory: 'Arbitre Botola Pro', levelDetail: 'D1', role: 'assistant', alsoOther: true),
        matches: [
          const MatchEntry(
            id: 'm',
            playedOn: '2026-11-08',
            competition: 'R2',
            role: 'Arbitre assistant',
            satisfaction: 4,
            feeling: 'Bon match',
            workPoints: ['Lecture du hors-jeu'],
            nextGoal: 'Être à hauteur',
            yellowCards: 3,
            redCards: 1,
            evals: {'concentration': 2},
          ),
          const MatchEntry(id: 'p', playedOn: '2026-11-20', competition: 'R2', role: 'Arbitre central', status: 'prevu', goal: 'Siffler tôt'),
        ],
        physical: [const PhysicalResult(id: 'x', test: 'coda', value: '10,31', doneOn: '2026-11-06', passed: true)],
        suggestions: [const CategorySuggestion(id: 's', country: 'MA', kind: 'categorie', label: 'Arbitre Botola Pro')],
      );
      final back = UserData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>);
      expect(back.profile.categoryLabel, 'Arbitre Botola Pro · D1');
      expect(back.profile.alsoOther, isTrue);
      expect(back.playedMatches.single.workPoints, ['Lecture du hors-jeu']);
      expect(back.playedMatches.single.eval('concentration'), 2);
      expect(back.playedMatches.single.redCards, 1);
      expect(back.plannedMatches.single.goal, 'Siffler tôt');
      expect(back.physical.single.passed, isTrue);
      expect(back.suggestions.single.label, 'Arbitre Botola Pro');
    });
    test('les anciens profils sont convertis', () {
      expect(Profile.fromRow({'level': 'jeune'}).level, 'jad');
      expect(Profile.fromRow({'level': 'inconnu'}).level, 'district');
      expect(Profile.fromRow({'level': 'federal', 'role': 'mixte'}).alsoOther, isTrue);
      expect(const Profile(level: 'ligue', levelDetail: 'R2').categoryLabel, 'Arbitre de ligue · R2');
    });
    test('dates', () {
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
      expect(addDaysIso(1, DateTime(2026, 12, 31)), '2027-01-01');
      expect(shortDate('2026-11-11'), '11 nov.');
      expect(frNumber(14.5), '14,5');
      expect(frNumber(15), '15');
    });
  });

  group('Contenu embarqué', () {
    test('toutes les questions sont valides et les identifiants uniques', () {
      final raw = jsonDecode(File('assets/content/questions.json').readAsStringSync()) as List;
      final qs = [for (final r in raw) Question.fromJson(r as Map<String, dynamic>)];
      expect(qs.length, greaterThanOrEqualTo(50));
      expect(qs.every((q) => q.isValid), isTrue);
      expect(qs.map((q) => q.id).toSet().length, qs.length);
      for (var l = 1; l <= 17; l++) {
        expect(qs.any((q) => q.law == l), isTrue, reason: 'loi $l sans question');
      }
      final lessons = jsonDecode(File('assets/content/lessons.json').readAsStringSync()) as List;
      expect(lessons.length, 17);
    });
  });

  group('Catégories', () {
    test('les catégories ajoutées apparaissent après les officielles, sans doublon', () {
      const sugg = [
        CategorySuggestion(id: '1', country: 'MA', kind: 'categorie', label: 'Arbitre Botola Pro', status: 'validee'),
        CategorySuggestion(id: '2', country: 'MA', kind: 'categorie', label: 'arbitre botola pro'),
        CategorySuggestion(id: '3', country: 'FR', kind: 'categorie', label: 'Arbitre futsal'),
        CategorySuggestion(id: '4', country: 'MA', kind: 'niveau', label: 'Élite A', categoryId: 'sugg:Arbitre Botola Pro'),
      ];
      final ma = categoryChoices('MA', sugg);
      expect(ma.first.id, 'ma_jeune');
      expect(ma.where((c) => c.added).map((c) => c.name), ['Arbitre Botola Pro']);
      expect(levelChoices('MA', customCategoryId, 'Arbitre Botola Pro', sugg), ['Élite A']);
      expect(levelChoices('FR', 'ligue', null, sugg), contains('R2'));
      expect(cleanLabel('  Arbitre   futsal  '), 'Arbitre futsal');
      expect(cleanLabel('x' * 80).length, CategorySuggestion.maxLength);
    });
    test('la difficulté suit l’expérience de la catégorie', () {
      expect(tierFor('jad'), Tier.beginner);
      expect(tierFor('federal'), Tier.expert);
      expect(tierFor('autre'), Tier.confirmed);
    });
  });

  group('Format examen', () {
    const q = ExamCase(id: 'e', law: 12, source: 's', situation: 's', options: ['a', 'b', 'c', 'd', 'e'], answers: {0, 2, 4}, explanation: '');
    test('notation de l’examen : 0,25 point par élément oublié ou en trop', () {
      expect(q.score({0, 2, 4}), 1);
      expect(q.score({0, 2}), .75);
      expect(q.score({0, 2, 4, 1}), .75);
      expect(q.score({1, 3}), 0);
    });
    test('les cas embarqués sont valides', () {
      final raw = jsonDecode(File('assets/content/exam_cases.json').readAsStringSync()) as List;
      final cases = [for (final r in raw) ExamCase.fromJson(r as Map<String, dynamic>)];
      expect(cases.length, greaterThanOrEqualTo(10));
      expect(cases.every((c) => c.isValid), isTrue);
      expect(cases.map((c) => c.id).toSet().length, cases.length);
    });
  });

  group('Rapport disciplinaire', () {
    final raw = jsonDecode(File('assets/content/report_cases.json').readAsStringSync()) as List;
    final cases = [for (final r in raw) ReportCase.fromJson(r as Map<String, dynamic>)];
    test('chaque rapport modèle obtient la note maximale', () {
      for (final c in cases) {
        expect(c.model.length, 5);
        final f = analyseReport(c.model.join('\n'), c);
        expect(f.parts, everyElement(isTrue), reason: c.id);
        expect(f.score, 20, reason: c.id);
        expect(f.personalData, isFalse, reason: 'modèle ${c.id} non anonyme');
      }
    });
    test('un rapport bâclé est sous la note éliminatoire', () {
      final f = analyseReport('Le joueur était agressif, je pense.', cases.first);
      expect(f.score, lessThan(ReportFeedback.passMark));
      expect(f.judgments, containsAll(['agressif', 'je pense']));
    });
    test('fautes sur avertir et exclure, écriture au passé', () {
      final f = analyseReport("J'exclu le joueur. Il a frappé l'adversaire, il a été exclut.", cases.first);
      expect(f.conjugation.length, 2);
      expect(f.pastForms, greaterThanOrEqualTo(2));
      expect(analyseReport("J'exclus le joueur et j’avertis le capitaine.", cases.first).conjugation, isEmpty);
    });
    test('anonymisation des noms et des licences', () {
      const t = 'Exclusion de M. Karim Benali (licence 2501234567), joueur n° 5.';
      expect(analyseReport(t, cases.first).personalData, isTrue);
      final a = anonymiseReport(t);
      expect(a, 'Exclusion de M. [NOM Prénom] (licence [licence]), joueur n° 5.');
      expect(analyseReport(a, cases.first).personalData, isFalse);
    });
  });

  group('Tests physiques', () {
    test('tests et barèmes selon la fonction et le niveau', () {
      final a = testsFor(const Profile(role: 'assistant', levelDetail: 'R2'));
      expect(a.map((x) => x.$1.id), ['sprint30', 'coda', 'ariet']);
      expect(a.first.$2.maxSeconds, 5.00);
      expect(a.last.$2.stage, '14-8');
      expect(testsFor(const Profile(role: 'assistant', levelDetail: 'R1')).first.$2.maxSeconds, 4.90);
      final c = testsFor(const Profile(role: 'central', levelDetail: 'R1'));
      expect(c.map((x) => x.$1.id), ['sds', 'sprint40']);
      expect(c.first.$2.distance!.single, 56);
      expect(testsFor(const Profile(role: 'central', levelDetail: 'R3')).single.$2.distance!.single, 53);
    });
    test('validation d’un résultat', () {
      const t = TestThreshold('x', '5"00', maxSeconds: 5.0);
      expect(passes(t, '4,88'), isTrue);
      expect(passes(t, '5"00'), isTrue);
      expect(passes(t, '5.01'), isFalse);
      expect(passes(t, 'vite'), isNull);
      const s = TestThreshold('x', 'Palier 14-8', stage: '14-8');
      expect(passes(s, '15-1'), isTrue);
      expect(passes(s, '14-8'), isTrue);
      expect(passes(s, '14-7'), isFalse);
      expect(passes(s, '13.5-8'), isFalse);
    });
    test('séance S.D.S. : 3 blocs de 5 répétitions', () {
      final plan = sdsPlan((single: 54, half: 32));
      expect(plan.where((x) => x.run).length, 45);
      expect(plan.fold<int>(0, (a, x) => a + x.seconds), 3 * 5 * 76 + 2 * 60);
      expect(plan.first.distance, '54 m');
    });
  });
}
