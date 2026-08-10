// lib/services/google_auth_config.dart
// RenkliOkeyScout — Google OAuth Konfiguration
//
// WICHTIG: Diese Werte kommen via --dart-define beim Build!
//   flutter build apk --debug \\
//     --dart-define=GOOGLE_WEB_CLIENT_ID=1234...apps.googleusercontent.com \\
//     --dart-define=GOOGLE_WEB_CLIENT_SECRET=GOCSPX-...
//
// Fallback auf DEFAULT (Placeholder) nur für Dev-Builds.

class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '808318424305-4d7jsbnlgvq2u1t3r7gqht9m77vc9v79.apps.googleusercontent.com',
  );

  static const String webClientSecret = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Wurde ein echter Key gesetzt?
  static bool get isConfigured =>
      webClientId != '808318424305-4d7jsbnlgvq2u1t3r7gqht9m77vc9v79.apps.googleusercontent.com' &&
      webClientId.isNotEmpty;
}
