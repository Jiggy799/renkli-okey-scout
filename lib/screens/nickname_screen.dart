// lib/screens/nickname_screen.dart
// RenkliOkeyScout — Nickname-Auswahl nach Google Sign-In
//
// User wählt EINMALIG seinen Okey-Nickname. Wird in profiles.username
// gespeichert und ist für andere Spieler sichtbar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class NicknameScreen extends StatefulWidget {
  const NicknameScreen({super.key});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = AuthService();
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _error;
  bool _checkingAvailability = false;
  bool? _isAvailable;

  static const _suggestions = [
    'Tugrul', 'Hakan', 'Ceyhan', 'Ömer',
    'C.78', 'Sahte', 'Joker', 'Schwarz',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkAvailability() async {
    final username = _controller.text.trim();
    if (username.length < 2) {
      setState(() => _isAvailable = null);
      return;
    }

    setState(() {
      _checkingAvailability = true;
      _isAvailable = null;
    });

    try {
      final res = await _supabase
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isAvailable = res == null;
          _checkingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAvailable = null;
          _checkingAvailability = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _controller.text.trim();
    if (_isAvailable == false) {
      setState(() => _error = 'Dieser Name ist schon vergeben');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Nicht angemeldet';

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'avatar_url': user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
        'username': username,
      });

      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleName = _auth.displayName;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
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
                  'Willkommen!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  googleName.isNotEmpty
                      ? 'Angemeldet als $googleName'
                      : 'Wähle deinen Spieler-Namen',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Nickname-Feld
                TextFormField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(12),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÄÖÜäöü0-9._-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Dein Okey-Nickname',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF8B949E)),
                    suffixIcon: _checkingAvailability
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
                            ),
                          )
                        : _isAvailable == true
                            ? const Icon(Icons.check_circle, color: Color(0xFF3FB950))
                            : _isAvailable == false
                                ? const Icon(Icons.error, color: Color(0xFFF85149))
                                : null,
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
                      borderSide: const BorderSide(color: Color(0xFF58A6FF), width: 2),
                    ),
                  ),
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.length < 2) return 'Mindestens 2 Zeichen';
                    if (v.length > 12) return 'Maximal 12 Zeichen';
                    return null;
                  },
                  onChanged: (_) => _checkAvailability(),
                ),

                // Status-Text
                if (_isAvailable == false) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Dieser Name ist schon vergeben',
                    style: TextStyle(color: Color(0xFFF85149), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_isAvailable == true) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '✓ Verfügbar',
                    style: TextStyle(color: Color(0xFF3FB950), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 24),

                // Vorschläge
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Vorschläge:',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((s) {
                    return ActionChip(
                      label: Text(s),
                      labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                      backgroundColor: const Color(0xFF21262D),
                      side: const BorderSide(color: Color(0xFF30363D)),
                      onPressed: () {
                        _controller.text = s;
                        _checkAvailability();
                      },
                    );
                  }).toList(),
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

                const SizedBox(height: 32),

                // Speichern-Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _isAvailable == false) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Loslegen',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Dein Nickname wird anderen Spielern angezeigt.\nDu kannst ihn später in den Einstellungen ändern.',
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
