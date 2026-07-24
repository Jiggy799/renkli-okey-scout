// lib/screens/profile_screen.dart
// RenkliOkeyScout — Profil bearbeiten (Nickname + Avatar)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _auth = AuthService();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _currentUsername;
  String? _email;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool? _isAvailable;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final res = await _supabase
        .from('profiles')
        .select('username, email, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    if (res != null && mounted) {
      setState(() {
        _currentUsername = res['username'];
        _email = res['email'];
        _avatarUrl = res['avatar_url'];
        _usernameController.text = res['username'] ?? '';
      });
    }
  }

  Future<void> _checkAvailability() async {
    final username = _usernameController.text.trim();
    if (username.length < 2 || username == _currentUsername) {
      setState(() => _isAvailable = null);
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
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
          _isCheckingAvailability = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCheckingAvailability = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final username = _usernameController.text.trim();

    if (username != _currentUsername && _isAvailable == false) {
      setState(() => _error = 'Name ist vergeben');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser!;
      await _supabase.from('profiles').update({
        'username': username,
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil gespeichert ✓')),
        );
        Navigator.pop(context);
      }
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
      appBar: AppBar(
        title: const Text('Profil bearbeiten', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Avatar
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: const Color(0xFF238636),
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? Text(
                            _currentUsername?.isNotEmpty == true
                                ? _currentUsername![0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // Email (read-only)
                if (_email != null) ...[
                  Center(
                    child: Text(
                      _email!,
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Nickname-Feld
                TextFormField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(12),
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÄÖÜäöü0-9._-]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Okey-Nickname',
                    labelStyle: const TextStyle(color: Color(0xFF8B949E)),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF8B949E)),
                    suffixIcon: _isCheckingAvailability
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
                  ),
                  validator: (val) {
                    final v = val?.trim() ?? '';
                    if (v.length < 2) return 'Mindestens 2 Zeichen';
                    if (v.length > 12) return 'Maximal 12 Zeichen';
                    return null;
                  },
                  onChanged: (_) => _checkAvailability(),
                ),

                if (_isAvailable == false) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Dieser Name ist schon vergeben',
                    style: TextStyle(color: Color(0xFFF85149), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],

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
                            'Speichern',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF58A6FF), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dein Nickname ist für andere Spieler sichtbar.\nAvatar + Email kommen von deinem Google-Account.',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
