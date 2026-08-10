// lib/screens/login_screen.dart
// RenkliOkeyScout — Login-Screen
//
// Auth-Methoden:
//   1. Anonym spielen (Primary, funktioniert sofort)
//   2. Email Magic Link (echte Auth, kein Setup nötig)
//   3. Mit Google anmelden (UI da, OAuth optional)
//   4. Mit Apple anmelden (TODO)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _isLoading = false;
  String? _error;
  String? _info;
  Future<void> _signIn(Future<void> Function() signInFn) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      await signInFn();
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'O K E Y',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFF30363D),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'RenkliOkeyScout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dein Okey-Score-Begleiter',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                ),
                const SizedBox(height: 32),

                // PRIMARY: Anonym spielen
                AuthButton(
                  icon: Icons.play_arrow,
                  label: 'Anonym spielen (sofort loslegen)',
                  color: const Color(0xFF238636),
                  onPressed: _isLoading
                      ? null
                      : () => _signIn(() async {
                            await _auth.signInAnonymously();
                          }),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Funktioniert ohne Konfig. Später kannst du dein Konto upgraden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder mit Email',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign-In (PRIMARY)
                AuthButton(
                  icon: Icons.login,
                  label: 'Mit Google anmelden',
                  color: const Color(0xFF4285F4),
                  onPressed: _isLoading
                      ? null
                      : () => _signIn(() async {
                            await _auth.signInWithGoogle();
                          }),
                ),
                const SizedBox(height: 12),

                // Apple Sign-In (TODO)
                AuthButton(
                  icon: Icons.apple,
                  label: 'Mit Apple anmelden (bald verfügbar)',
                  color: const Color(0xFF8B949E),
                  onPressed: null,
                ),

                // Info (Magic Link sent)
                if (_info != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3FB950)),
                    ),
                    child: Text(
                      _info!,
                      style: const TextStyle(color: Color(0xFF3FB950), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                // Fehler
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDA3633).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDA3633)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFDA3633), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFF58A6FF)),
                ],

                const SizedBox(height: 24),
                const Text(
                  'Mit dem Anmelden werden dein Benutzername\nund Avatar gespeichert.',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
