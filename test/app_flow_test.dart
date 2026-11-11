import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sifflet_academie/data/content_repository.dart';
import 'package:sifflet_academie/data/local_store.dart';
import 'package:sifflet_academie/state/app_state.dart';
import 'package:sifflet_academie/ui/app.dart';

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
      await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
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
    expect(find.text('Indiquez l’e-mail d’un parent ou tuteur.'), findsOneWidget);
    expect(state.needsOnboarding, isTrue);
  });

  testWidgets('parcours complet : profil, quiz, formation, carnet', (tester) async {
    final state = await boot(tester);
    await onboard(tester);
    expect(state.needsOnboarding, isFalse);
    expect(find.text('ARBITRE STAGIAIRE'), findsOneWidget);
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

    // Carnet de match.
    await tester.tap(find.text('Suivi'));
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Ajouter un match'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Compétition'), 'U19 Régional 1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Note de l’observateur (sur 20, facultatif)'), '25');
    await tapIt(tester, find.text('Enregistrer le match'));
    expect(find.text('La note doit être un nombre entre 0 et 20.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Note de l’observateur (sur 20, facultatif)'), '14,5');
    await tapIt(tester, find.text('Enregistrer le match'));
    expect(state.data.matches.single.observerNote, 14.5);
    expect(find.text('Auto-évaluation'), findsOneWidget);
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
