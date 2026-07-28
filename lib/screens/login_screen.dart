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
  bool _showMagicLink = false;
  final _emailController = TextEditingController();

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

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Bitte gültige Email eingeben');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
      _info = null;
    });
    try {
      await _auth.signInWithMagicLink(email);
      if (mounted) {
        setState(() {
          _info = '✓ Magic Link gesendet! Prüfe dein Email-Postfach und klicke den Link.';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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

                // Email Magic Link
                if (!_showMagicLink)
                  AuthButton(
                    icon: Icons.email_outlined,
                    label: 'Email Magic Link',
                    color: const Color(0xFF1F6FEB),
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _showMagicLink = true),
                  )
                else
                  _buildMagicLinkForm(),

                const SizedBox(height: 24),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'oder mit Konto',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFF30363D))),
                  ],
                ),
                const SizedBox(height: 16),

                // Google Sign-In (funktioniert erst nach OAuth-Setup)
                AuthButton(
                  icon: Icons.login,
                  label: 'Mit Google anmelden',
                  color: const Color(0xFF4285F4).withValues(alpha: 0.4),
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

  Widget _buildMagicLinkForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F6FEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.email_outlined, color: Color(0xFF1F6FEB), size: 18),
              SizedBox(width: 8),
              Text(
                'Email Magic Link',
                style: TextStyle(
                  color: Color(0xFF1F6FEB),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Wir schicken dir einen Login-Link per Email.\nKeine Passwörter, kein Setup.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'deine@email.de',
              hintStyle: const TextStyle(color: Color(0xFF6E7681)),
              prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF8B949E)),
              filled: true,
              fillColor: const Color(0xFF0D1117),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF30363D)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF30363D)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1F6FEB), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AuthButton(
                  icon: Icons.send,
                  label: 'Magic Link senden',
                  color: const Color(0xFF1F6FEB),
                  onPressed: _isLoading ? null : _sendMagicLink,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8B949E)),
                onPressed: () => setState(() {
                  _showMagicLink = false;
                  _emailController.clear();
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
