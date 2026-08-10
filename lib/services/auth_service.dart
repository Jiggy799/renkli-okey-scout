// lib/services/auth_service.dart
// RenkliOkeyScout — Authentication service
//
// Bietet mehrere Authentifizierungsmethoden:
//   1. Google Sign-In (Optional — braucht OAuth Setup)
//   2. Apple Sign-In (TODO)
//   3. Email Magic Link (EINFACHSTE echte Auth, kein Setup nötig!)
//   4. Email + Password (klassisch)
//   5. Anonymous Sign-In (Demo/Fallback)
//
// User-Profil (Username, Avatar) wird automatisch vom Provider übernommen.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  /// Aktuell angemeldeter User (oder null).
  User? get currentUser => _supabase.auth.currentUser;

  /// Auth-State-Stream für Live-Updates.
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Bereits angemeldet?
  bool get isSignedIn => currentUser != null;

  /// Google Sign-In (native auf Android, OAuth-Web-Flow auf iOS).
  ///
  /// Voraussetzung: SHA-1 Fingerprint + Web-Client-ID in Supabase
  /// konfiguriert (siehe README).
  Future<AuthResponse> signInWithGoogle() async {
    // Web-Client-ID (für ID-Token, nicht für OAuth-Web-Flow).
    // Wird in der Google Cloud Console unter "OAuth 2.0 Client IDs" erstellt.
    // User muss ECHTE Client ID in google-services.json setzen.
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: const String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '808318424305-4d7jsbnlgvq2u1t3r7gqht9m77vc9v79.apps.googleusercontent.com',
      ),
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw AuthException('Google Sign-In abgebrochen');
    }

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw AuthException('Kein ID-Token von Google erhalten');
    }

    final accessToken = googleAuth.accessToken;

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Apple Sign-In (nativ auf iOS, Web-Flow auf Android).
  ///
  /// TODO: Implementieren wenn iOS-Support dazukommt.
  Future<AuthResponse> signInWithApple() async {
    throw UnimplementedError('Apple Sign-In noch nicht implementiert');
  }

  /// Anonymer Sign-In (Demo/Fallback).
  ///
  /// Für Test-Accounts ohne Google/Apple. Username wird später
  /// in `profiles` Tabelle gesetzt.
  Future<AuthResponse> signInAnonymously() async {
    return await _supabase.auth.signInAnonymously();
  }

  /// Email Magic Link Auth (KEIN Google OAuth nötig!)
  ///
  /// Supabase schickt einen Login-Link an die angegebene Email.
  /// User klickt Link → automatisch eingeloggt.
  ///
  /// Vorteile:
  /// - Funktioniert sofort (kein OAuth Setup)
  /// - Kein Google Cloud Console nötig
  /// - Keine SHA-1 Fingerabdrücke nötig
  /// - Echte Identität (Email verifiziert)
  Future<void> signInWithMagicLink(String email, {String? redirectTo}) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectTo,
    );
  }

  /// Email + Password Auth (klassisch)
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
    bool isSignUp = false,
  }) async {
    if (isSignUp) {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
    );
    }
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sendet OTP-Code per Email (alternative zu Magic Link)
  Future<void> sendOtpCode(String email) async {
    await _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  /// Logout.
  Future<void> signOut() async {
    // Google Sign-In abmelden (falls aktiv)
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await _supabase.auth.signOut();
  }

  /// Username aus Auth-Metadaten holen.
  /// Für anonyme User: Kurze eindeutige ID (8 Zeichen) damit Username UNIQUE constraint nicht verletzt.
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Gast';

    final meta = user.userMetadata;
    if (meta != null && meta['full_name'] != null) return meta['full_name'];
    if (meta != null && meta['name'] != null) return meta['name'];
    if (meta != null && meta['email'] != null) {
      return meta['email'].toString().split('@').first;
    }

    // Anonym: eindeutige ID aus User-ID ableiten
    // Erste 8 Zeichen der UUID = garantiert eindeutig pro User
    final shortId = user.id.replaceAll('-', '').substring(0, 8);
    final name = 'Spieler_' + shortId; return name;
  }

  /// Avatar-URL aus Auth-Metadaten holen.
  String? get avatarUrl {
    final user = currentUser;
    if (user == null) return null;

    final meta = user.userMetadata;
    return meta?['avatar_url'] ?? meta?['picture'];
  }
}

/// Helper Widget für Login-Buttons.
class AuthButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const AuthButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
