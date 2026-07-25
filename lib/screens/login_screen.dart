// lib/screens/login_screen.dart
// RenkliOkeyScout — Login-Screen
//
// 3 Optionen:
//   1. Anonym spielen (Primary — funktioniert sofort, keine Konfig)
//   2. Mit Google anmelden (Optional — braucht OAuth Client ID)
//   3. Mit Apple anmelden (TODO)

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

  Future<void> _signIn(Future<void> Function() signInFn) async {
    setState(() {
      _isLoading = true;
      _error = null;
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
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'O K E Y',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2
                        ..color = const Color(0xFF30363D),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 48),

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
                const SizedBox(height: 32),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF30363D))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder mit Konto',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 24),

                // Google Sign-In (funktioniert erst nach OAuth-Setup)
                AuthButton(
                  icon: Icons.login,
                  label: 'Mit Google anmelden',
                  color: const Color(0xFF4285F4).withValues(alpha: 0.5),
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

                const SizedBox(height: 48),
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
