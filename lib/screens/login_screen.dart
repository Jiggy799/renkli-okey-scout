// lib/screens/login_screen.dart
// RenkliOkeyScout — Login-Screen mit Google + Anonymous
//
// 3 Buttons:
//   - Mit Google anmelden (Primary)
//   - Mit Apple anmelden (TODO)
//   - Anonym spielen (Demo)

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

  Future<void> _signInGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _auth.signInWithGoogle();
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInAnonymous() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _auth.signInAnonymously();
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
                // Logo
                const Text(
                  '🀄️',
                  style: TextStyle(fontSize: 80),
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

                // Google Sign-In Button
                AuthButton(
                  icon: Icons.login,
                  label: 'Mit Google anmelden',
                  color: const Color(0xFF4285F4),
                  onPressed: _isLoading ? null : _signInGoogle,
                ),
                const SizedBox(height: 12),

                // Apple Sign-In (deaktiviert)
                AuthButton(
                  icon: Icons.apple,
                  label: 'Mit Apple anmelden (bald verfügbar)',
                  color: const Color(0xFF8B949E),
                  onPressed: null,
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Container(height: 1, color: const Color(0xFF30363D))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                    Expanded(child: Container(height: 1, color: const Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 24),

                // Anonymous
                AuthButton(
                  icon: Icons.person_outline,
                  label: 'Anonym spielen (Demo)',
                  color: const Color(0xFF21262D),
                  onPressed: _isLoading ? null : _signInAnonymous,
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

                // Loading
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFF58A6FF)),
                ],

                const SizedBox(height: 48),
                const Text(
                  'Mit dem Anmelden akzeptierst du, dass dein\nBenutzername und Avatar gespeichert werden.',
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
