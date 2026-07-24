// lib/services/auth_service.dart
// RenkliOkeyScout — Authentication service
//
// Bietet drei Authentifizierungsmethoden:
//   1. Google Sign-In (Primary für Android)
//   2. Apple Sign-In (Primary für iOS) — TODO
//   3. Anonymous Sign-In (Demo/Fallback)
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
    final googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId:
          '808318424305-4d7jsbnlgvq2u1t3r7gqht9m77vc9v79.apps.googleusercontent.com', // PLACEHOLDER
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

  /// Logout.
  Future<void> signOut() async {
    // Google Sign-In abmelden (falls aktiv)
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}

    await _supabase.auth.signOut();
  }

  /// Username aus Auth-Metadaten holen.
  String get displayName {
    final user = currentUser;
    if (user == null) return 'Gast';

    final meta = user.userMetadata;
    if (meta == null) return 'Spieler';

    return meta['full_name'] ??
        meta['name'] ??
        meta['email']?.toString().split('@').first ??
        'Spieler';
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
