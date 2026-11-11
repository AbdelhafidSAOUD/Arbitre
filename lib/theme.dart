import 'package:material_ui/material_ui.dart';

/// Couleurs de la marque : pelouse, cartons jaune et rouge, tableau de match.
@immutable
class SiffletColors extends ThemeExtension<SiffletColors> {
  const SiffletColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.pitch,
    required this.pitchSoft,
    required this.card,
    required this.cardSoft,
    required this.onCard,
    required this.red,
    required this.redSoft,
    required this.navy,
    required this.onNavy,
    required this.grass,
    required this.grass2,
    required this.attacker,
  });

  final Color bg, surface, surface2, ink, muted, line;
  final Color pitch, pitchSoft, card, cardSoft, onCard, red, redSoft;
  final Color navy, onNavy, grass, grass2, attacker;

  static const light = SiffletColors(
    bg: Color(0xFFEEF2EC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF6F8F4),
    ink: Color(0xFF13203A),
    muted: Color(0xFF5B6778),
    line: Color(0xFFD9E0D6),
    pitch: Color(0xFF1D7447),
    pitchSoft: Color(0xFFDCEFE3),
    card: Color(0xFFF2B705),
    cardSoft: Color(0xFFFFF3C7),
    onCard: Color(0xFF1B1606),
    red: Color(0xFFCF3428),
    redSoft: Color(0xFFFBE3E0),
    navy: Color(0xFF13203A),
    onNavy: Color(0xFFF3F6FB),
    grass: Color(0xFF2F8D56),
    grass2: Color(0xFF2A804E),
    attacker: Color(0xFF1D5BD1),
  );

  static const dark = SiffletColors(
    bg: Color(0xFF0D141F),
    surface: Color(0xFF162030),
    surface2: Color(0xFF1B2738),
    ink: Color(0xFFE8EDF4),
    muted: Color(0xFF9AA7B8),
    line: Color(0xFF28364A),
    pitch: Color(0xFF4CC387),
    pitchSoft: Color(0xFF143326),
    card: Color(0xFFFFC927),
    cardSoft: Color(0xFF3A300C),
    onCard: Color(0xFF1B1606),
    red: Color(0xFFFF6A5C),
    redSoft: Color(0xFF3E1C19),
    navy: Color(0xFF22314A),
    onNavy: Color(0xFFF3F6FB),
    grass: Color(0xFF23683F),
    grass2: Color(0xFF1F5E39),
    attacker: Color(0xFF4F8CFF),
  );

  @override
  SiffletColors copyWith() => this;

  @override
  SiffletColors lerp(ThemeExtension<SiffletColors>? other, double t) =>
      t < .5 ? this : (other as SiffletColors? ?? this);
}

extension SiffletTheme on BuildContext {
  SiffletColors get sc => Theme.of(this).extension<SiffletColors>()!;
}

const kBody = 'Barlow';
const kDisplay = 'BarlowCondensed';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? SiffletColors.dark : SiffletColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.pitch,
    brightness: brightness,
  ).copyWith(
    primary: c.pitch,
    onPrimary: Colors.white,
    secondary: c.card,
    onSecondary: c.onCard,
    error: c.red,
    surface: c.surface,
    onSurface: c.ink,
    outline: c.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kBody,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
  );
  TextStyle display(double size, [FontWeight w = FontWeight.w800]) => TextStyle(
        fontFamily: kDisplay,
        fontSize: size,
        fontWeight: w,
        height: 1.05,
        color: c.ink,
      );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: kBody)
        .copyWith(
          headlineLarge: display(34),
          headlineMedium: display(28),
          titleLarge: display(22, FontWeight.w700),
          titleMedium: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16).copyWith(color: c.ink),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.cardSoft,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: kBody, fontSize: 12, fontWeight: FontWeight.w600, color: c.ink),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.card,
        foregroundColor: c.onCard,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: kBody, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size.fromHeight(48),
        side: BorderSide(color: c.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: kBody, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.line, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.line, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: TextStyle(color: c.bg, fontFamily: kBody, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
