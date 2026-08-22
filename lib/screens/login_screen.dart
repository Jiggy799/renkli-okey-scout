// lib/screens/login_screen.dart
// RenkliOkeyScout — Login Screen (MINIMAL)
//
// ZWEI Optionen:
// 1. Mit Google anmelden (PRIMARY, gross)
// 2. Anonym spielen (SECONDARY, klein)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../services/google_auth_config.dart';

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
      // Already anonymous user tried signInAnonymously again
      if (e.toString().contains('anonymous')) {
        if (mounted) context.go('/');
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGoogleKey = GoogleAuthConfig.isConfigured;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                const Text(
                  'OKEY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 16,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'RenkliOkeyScout',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                ),
                const SizedBox(height: 48),

                // PRIMARY: Mit Google anmelden
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: hasGoogleKey && !_isLoading
                        ? () => _signIn(() async {
                              await _auth.signInWithGoogle();
                            })
                        : null,
                    icon: const Icon(Icons.login, color: Colors.white, size: 22),
                    label: const Text(
                      'Mit Google anmelden',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF30363D),
                      disabledForegroundColor: const Color(0xFF6E7681),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                if (!hasGoogleKey) ...[
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Google OAuth noch nicht konfiguriert.\nSiehe GOOGLE_OAUTH_SETUP.md',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFFF0C000), fontSize: 11),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 24),

                // SECONDARY: Anonym spielen (nur wenn NICHT schon anonymous)
                if (!_auth.isAnonymousUser)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _signIn(() async {
                                await _auth.signInAnonymously();
                              }),
                      icon: const Icon(Icons.person_outline, color: Color(0xFF8B949E)),
                      label: const Text(
                        'Anonym spielen',
                        style: TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF30363D)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Kein Account nötig. Spieler_XXXX als Name.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6E7681), fontSize: 11),
                  ),
                ),

                // Fehler
                if (_error != null) ...[
                  const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
