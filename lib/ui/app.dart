import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'auth_screen.dart';
import 'brand.dart';
import 'common.dart';
import 'home_tab.dart';
import 'learn_tab.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'track_tab.dart';
import 'training_tab.dart';

class SiffletApp extends StatelessWidget {
  const SiffletApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Sifflet Académie',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: const Locale('fr'),
          supportedLocales: const [Locale('fr')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            if (!state.profile.largeText) return child!;
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * 1.15)),
              child: child!,
            );
          },
          home: const _Gate(),
        ),
      ),
    );
  }
}

/// Aiguillage : connexion → profil → application.
class _Gate extends StatelessWidget {
  const _Gate();
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    if (!s.ready) return const _Splash();
    if (!s.isSignedIn) return const AuthScreen();
    if (s.needsOnboarding) return const OnboardingScreen();
    return const Shell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: BrandMark(size: 44)));
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const BrandMark(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Mon profil',
              child: ActionChip(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
                backgroundColor: c.surface,
                side: BorderSide(color: c.line),
                shape: const StadiumBorder(),
                avatar: Container(width: 9, height: 12, decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(2))),
                label: Text('${s.level.name.toUpperCase()} · ${s.profile.xp} XP',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5, color: c.ink)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: IndexedStack(index: tab, children: const [HomeTab(), TrainingTab(), LearnTab(), TrackTab()]),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: 'S’entraîner'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Formation'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Suivi'),
        ],
      ),
    );
  }
}
