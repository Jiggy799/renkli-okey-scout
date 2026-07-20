// lib/screens/home_screen.dart
// RenkliOkeyScout — Home: Username + How to Play

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _isLoading = true);

    // Anonymous sign-in if needed
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final anonResult =
          await Supabase.instance.client.auth.signInAnonymously();
      user = anonResult.user;
    }

    // Upsert profile
    await Supabase.instance.client.from('profiles').upsert({
      'id': user!.id,
      'username': username,
    });

    if (mounted) {
      context.go('/lobby');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),

              // Custom logo: Okey stones + camera
              _buildLogo(),

              const SizedBox(height: 16),
              const Text(
                'RenkliOkeyScout',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Okey Score Tracker',
                style: TextStyle(
                  color: Color(0xFF8B949E),
                  fontSize: 16,
                ),
              ),
              const Spacer(),

              // Username form
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Dein Spielername',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    prefixIcon:
                        const Icon(Icons.person, color: Color(0xFF8B949E)),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF30363D)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF58A6FF), width: 2),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Bitte Namen eingeben';
                    }
                    if (val.trim().length < 2) {
                      return 'Mindestens 2 Zeichen';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _continue(),
                ),
              ),
              const SizedBox(height: 24),

              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Weiter',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Demo Mode button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go('/demo-lobby'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF0C000),
                    side: const BorderSide(color: Color(0xFFF0C000)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.science, color: Color(0xFFF0C000), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Demo Modus',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Regelwerk button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : () => context.push('/rules'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text(
                    'Regelwerk lesen',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),

              // How it works
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'So funktioniert\'s',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ruleRow(Icons.people, '4 Spieler an einem Tisch'),
                    _ruleRow(Icons.qr_code, 'QR-Code zum Beitreten'),
                    _ruleRow(Icons.camera_alt, 'Steine scannen (optional)'),
                    _ruleRow(Icons.score, 'Strafpunkte automatisch berechnet'),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF58A6FF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Custom logo: 4 Okey stones (tiles) + camera icon overlaid
  Widget _buildLogo() {
    return SizedBox(
      width: 120,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 4 coloured tiles arranged in a row
          Positioned(
            left: 0,
            child: _tile(Color(0xFFF0C000), '8', 34),
          ),
          Positioned(
            left: 26,
            child: _tile(Color(0xFF1F6FEB), '13', 34),
          ),
          Positioned(
            left: 52,
            child: _tile(Color(0xFFDA3633), '7', 34),
          ),
          Positioned(
            left: 78,
            child: _tile(Color(0xFF6E7681), '3', 34),
          ),
          // Camera icon overlaid bottom-right
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Color(0xFF30363D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                color: Color(0xFFF0C000),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Color color, String number, double size) {
    return Container(
      width: size,
      height: size * 1.35,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: color == Color(0xFFF0C000) || color == Color(0xFF6E7681)
                ? Colors.black
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
