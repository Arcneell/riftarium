/// Configuration figée au build via `--dart-define` (voir WORKFLOW.md §6).
///
/// Exemples :
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8889/api   (émulateur Android)
///   flutter run --dart-define=API_BASE_URL=http://localhost:8889/api  (simulateur iOS)
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://riftarium.re/api',
  );

  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://riftarium.re',
  );

  /// En-tête qui signale un client natif à l'API : la réponse d'authentification
  /// porte alors le jeton dans son corps, avec une durée de vie longue.
  static const String clientHeader = 'X-Riftarium-Client';
  static const String clientHeaderValue = 'mobile';
}
