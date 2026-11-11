/// Configuration de l'application, injectée à la compilation :
///
///   flutter run --dart-define-from-file=config/dev.json
///
/// Sans SUPABASE_URL ni SUPABASE_KEY, l'application démarre en
/// « mode local » : aucun compte, aucune donnée envoyée, tout reste sur
/// l'appareil. Pratique pour développer et tester.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Clé publique du projet (« publishable key », sb_publishable_…, ou
  /// ancienne clé « anon »). Elle peut figurer dans l'application : la
  /// sécurité repose sur les règles RLS de la base.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');
  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/confidentialite',
  );
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'contact@example.com',
  );

  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// À changer à chaque mise à jour de la politique de confidentialité :
  /// les utilisateurs devront l'accepter de nouveau.
  static const privacyVersion = '2026-11';

  /// Âge en dessous duquel l'accord d'un parent est demandé
  /// (15 ans en France ; entre 13 et 16 ans selon les pays de l'UE).
  static const digitalConsentAge = 15;

  static const examQuestions = 30;
  static const examMinutes = 20;
  static const examPassRatio = 0.8;
  static const secondsPerQuestion = 15;
}
