import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sifflet_academie/data/content_repository.dart';
import 'package:sifflet_academie/data/local_store.dart';
import 'package:sifflet_academie/state/app_state.dart';
import 'package:sifflet_academie/ui/app.dart';
import 'package:sifflet_academie/ui/report_screen.dart';

/// Parcours complet en mode local : création du profil, quiz, résultat,
/// formation, carnet de match, profil.
void main() {
  Future<AppState> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final state = AppState(store: store, content: ContentRepository(store), random: Random(7));
    await tester.runAsync(state.init);
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SiffletApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  /// Fait défiler jusqu'à l'élément puis appuie dessus.
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    if (f.evaluate().isEmpty) {
      // Défile dans l'écran au premier plan (la dernière liste verticale).
      // (les champs de texte sur plusieurs lignes ont aussi leur Scrollable)
      final lists = find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)).first;
      // Parcourt la page de haut en bas sans glisser du doigt : un glissement
      // pourrait tomber sur un champ de texte qui défile pour son compte.
      final pos = tester.state<ScrollableState>(lists).position;
      for (var y = 0.0; f.evaluate().isEmpty && y <= pos.maxScrollExtent + 300; y += 300) {
        pos.jumpTo(y.clamp(0, pos.maxScrollExtent));
        await tester.pump();
      }
    }
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> pickYear(WidgetTester tester, String year) async {
    await tester.tap(find.text('Année de naissance'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text(year).last, 48, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(year).last);
    await tester.pumpAndSettle();
  }

  Future<void> onboard(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.text('VOTRE PROFIL D’ARBITRE'), findsOneWidget);
    await pickYear(tester, '2005');
    await tapIt(tester, find.textContaining('J’ai lu et j’accepte'));
    await tapIt(tester, find.text('Commencer'));
  }

  testWidgets('inscription refusée sans accepter la politique de confidentialité', (tester) async {
    final state = await boot(tester);
    await pickYear(tester, '2005');
    await tapIt(tester, find.text('Commencer'));
    expect(find.text('Acceptez la politique de confidentialité pour continuer.'), findsOneWidget);
    expect(state.needsOnboarding, isTrue);
  });

  testWidgets('un mineur doit fournir l’accord parental', (tester) async {
    final state = await boot(tester);
    await pickYear(tester, '${DateTime.now().year - 12}');
    expect(find.text('Accord parental'), findsOneWidget);
    await tapIt(tester, find.textContaining('J’ai lu et j’accepte'));
    await tapIt(tester, find.text('Commencer'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
    await tester.pumpAndSettle();
    expect(find.text('Indiquez l’e-mail d’un parent ou tuteur.'), findsOneWidget);
    expect(state.needsOnboarding, isTrue);
  });

  testWidgets('parcours complet : profil, quiz, formation, carnet', (tester) async {
    final state = await boot(tester);
    await onboard(tester);
    expect(state.needsOnboarding, isFalse);
    expect(find.text('ARBITRE DE DISTRICT'), findsOneWidget);
    expect(find.text('PROGRAMME DU JOUR'), findsOneWidget);

    // Quiz rapide : on répond toujours A.
    await tapIt(tester, find.text('QUIZ RAPIDE'));
    for (var i = 0; i < 10; i++) {
      await tapIt(tester, find.text('A'));
      await tapIt(tester, find.text(i < 9 ? 'Question suivante' : 'Voir mon résultat'));
    }
    expect(find.textContaining('XP au total'), findsOneWidget);
    expect(state.data.sessions.single.total, 10);
    expect(state.data.badges, contains('first'));
    expect(state.profile.streak, 1);
    final answered = state.data.laws.values.fold<int>(0, (a, t) => a + t.total);
    expect(answered, 10);
    await tapIt(tester, find.text('Terminer'));

    // Formation : fiche de la loi 11 avec exemple de hors-jeu.
    await tester.tap(find.text('Formation'));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Le hors-jeu'));
    expect(find.text('EXEMPLE AU MOMENT DE LA PASSE'), findsNothing); // titre en casse normale
    expect(find.text('Exemple au moment de la passe'), findsOneWidget);
    expect(state.data.readLessons.containsKey(11), isTrue);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Match à venir avec un objectif, puis débriefing.
    await tester.tap(find.text('Matchs'));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Ajouter'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Compétition'), 'U19 Régional 1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mon objectif pour ce match'), 'Siffler tôt');
    await tapIt(tester, find.text('Enregistrer le match'));
    expect(state.data.plannedMatches.single.goal, 'Siffler tôt');
    expect(find.text('Objectif : '), findsNothing); // affiché en texte enrichi
    await tapIt(tester, find.text('Match joué : débriefer'));
    await tapIt(tester, find.text('Enregistrer le débriefing'));
    expect(find.text('Indiquez au moins votre satisfaction globale.'), findsOneWidget);
    await tapIt(tester, find.text('Satisfait'));
    await tapIt(tester, find.text('Timing des cartons'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Note de l’observateur (sur 20, facultatif)'), '25');
    await tapIt(tester, find.text('Enregistrer le débriefing'));
    expect(find.text('La note doit être un nombre entre 0 et 20.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Note de l’observateur (sur 20, facultatif)'), '14,5');
    await tapIt(tester, find.text('Enregistrer le débriefing'));
    final m = state.data.matches.single;
    expect(m.planned, isFalse);
    expect(m.satisfaction, 4);
    expect(m.workPoints, ['Timing des cartons']);
    expect(m.observerNote, 14.5);

    // Physique : les tests de l'arbitre central.
    await tester.tap(find.text('Physique'));
    await tester.pumpAndSettle();
    expect(find.text('S.D.S. (simple, double, simple)'), findsWidgets);
  });

  testWidgets('profil : catégorie ajoutée par l’arbitre', (tester) async {
    final state = await boot(tester);
    await tapIt(tester, find.text('Maroc'));
    await tapIt(tester, find.text('Ma catégorie n’est pas dans la liste'));
    await tester.enterText(find.widgetWithText(TextField, 'Nom de la catégorie'), 'Arbitre Botola Pro');
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Arbitre assistant'));
    await onboard(tester);
    expect(state.profile.country, 'MA');
    expect(state.profile.level, 'autre');
    expect(state.profile.customCategory, 'Arbitre Botola Pro');
    expect(state.profile.isAssistant, isTrue);
    expect(state.data.suggestions.single.label, 'Arbitre Botola Pro');
    expect(find.text('ARBITRE BOTOLA PRO'), findsOneWidget);
  });

  testWidgets('format examen et atelier rapport', (tester) async {
    final state = await boot(tester);
    await onboard(tester);
    await tester.tap(find.text('Entraîner'));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('FORMAT EXAMEN'));
    for (var i = 0; i < 5; i++) {
      await tapIt(tester, find.text('Rapport'));
      await tapIt(tester, find.text('Valider mes décisions'));
      await tapIt(tester, find.text(i < 4 ? 'Cas suivant' : 'Voir ma note'));
    }
    expect(state.data.sessions.last.mode, Labels.examCases);
    expect(state.data.sessions.last.total, 20);
    await tapIt(tester, find.text('Terminer'));

    await tapIt(tester, find.text('RAPPORT DISCIPLINAIRE'));
    final model = state.content.reportCases.first.model.join('\n');
    final field = find.widgetWithText(TextField, 'Votre rapport');
    await tester.scrollUntilVisible(field, 200,
        scrollable: find.descendant(of: find.byType(ReportScreen), matching: find.byType(Scrollable)).first);
    await tester.enterText(field, model);
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Corriger mon rapport'));
    expect(state.data.sessions.last.mode, Labels.report);
    expect(state.data.sessions.last.correct, 20); // le modèle obtient 20/20
  });

  testWidgets('examen blanc : pas de correction avant la fin', (tester) async {
    final state = await boot(tester);
    await onboard(tester);
    await tapIt(tester, find.text('EXAMEN BLANC'));
    expect(find.textContaining('correction à la fin'), findsOneWidget);
    for (var i = 0; i < 30; i++) {
      await tapIt(tester, find.text('B'));
      expect(find.text('BONNE DÉCISION'), findsNothing);
      expect(find.text('MAUVAISE DÉCISION'), findsNothing);
      await tapIt(tester, find.text(i < 29 ? 'Valider et continuer' : 'Terminer l’examen'));
    }
    await tester.pumpAndSettle();
    final session = state.data.sessions.single;
    expect(session.isExam, isTrue);
    expect(session.total, 30);
    expect(find.textContaining('EXAMEN'), findsWidgets);
  });
}
