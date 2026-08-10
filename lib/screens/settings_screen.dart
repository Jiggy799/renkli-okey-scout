// lib/screens/settings_screen.dart
// RenkliOkeyScout — Settings / Profile screen

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/gemini_vision_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;
  String? _email;

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _username = profile?['username'];
        _email = user.email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Einstellungen', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFF238636),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (_username ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username ?? 'Lädt...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email ?? 'Anonym',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Rules section
          const Text(
            'Spielregeln',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _ruleCard(
            'Gösterge / Tischfarbe',
            'Der offene Stein bestimmt die Tischfarbe und damit den Basis-Multiplikator:'
            '\n• Gelb ×2 · Blau ×3 · Rot ×4 · Schwarz ×5',
            Icons.palette,
          ),
          _ruleCard(
            'Okey atmak',
            'Wenn der Gewinner den Okey als letzten Stein abwirft → ×2 auf alle Strafen',
            Icons.stars,
          ),
          _ruleCard(
            'Çifte Gitmek',
            'Wenn ein Verlierer mit 7 Paaren rausging → ×2 auf eigene Strafe'
            '\n(Hinweis: Gewinner kann auch Çifte sein → kein Nachteil)',
            Icons.group_add,
          ),
          _ruleCard(
            'Gösterme Strafe',
            'Wenn ein Spieler den echten Gösterge offen auf der Hand hält:'
            '\nAlle anderen erhalten sofort 1×Tischfarbe Strafpunkte',
            Icons.warning_amber,
          ),
          _ruleCard(
            'Strafpunkte',
            'Verlierer zählen ihre Steine die nicht in Reihen/Paare passen.'
            '\nMinuspunkte × Tischfarbe × Okey × Çifte = finale Strafe',
            Icons.calculate,
          ),

          const SizedBox(height: 24),

          // Gemini API Key
          const Text(
            'KI-Erkennung',
            style: TextStyle(
              color: Color(0xFF8B949E),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _geminiKeyCard(),

          const SizedBox(height: 24),

          // App info
          const Center(
            child: Text(
              'RenkliOkeyScout v2.2.0',
              style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String? _geminiKey;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadGeminiKey();
  }

  Future<void> _loadGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString('gemini_api_key') ?? '';
    if (key.isNotEmpty) {
      GeminiVisionService.initialize(key);
    }
    if (mounted) setState(() => _geminiKey = key.isEmpty ? null : key);
  }

  Future<void> _saveGeminiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove('gemini_api_key');
    } else {
      await prefs.setString('gemini_api_key', key);
      GeminiVisionService.initialize(key);
    }
    if (mounted) setState(() => _geminiKey = key.isEmpty ? null : key);
  }

  Widget _geminiKeyCard() {
    final hasKey = _geminiKey != null && _geminiKey!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasKey ? const Color(0xFF3FB950) : const Color(0xFFF0C000),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasKey ? Icons.check_circle : Icons.key,
                color: hasKey ? const Color(0xFF3FB950) : const Color(0xFFF0C000),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gemini API-Key',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasKey)
                IconButton(
                  icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility),
                  color: const Color(0xFF8B949E),
                  onPressed: () => setState(() => _keyVisible = !_keyVisible),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasKey
                ? 'Key gesetzt — Foto-Erkennung aktiv'
                : 'Ohne Key: Stub-Heuristik (zufällige Steine).',
            style: TextStyle(
              color: hasKey ? const Color(0xFF3FB950) : const Color(0xFFF0C000),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _geminiKey ?? '',
            obscureText: !_keyVisible,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'AIza... oder AQ.Ab...',
              hintStyle: const TextStyle(color: Color(0xFF6E7681)),
              prefixIcon: const Icon(Icons.key, color: Color(0xFF8B949E), size: 18),
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
            onFieldSubmitted: _saveGeminiKey,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _saveGeminiKey(''),
                  child: const Text('Löschen'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final controller = TextEditingController(text: _geminiKey ?? '');
                    showDialog(
                      context: context,
                      builder: (ctx) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF161B22),
                          title: const Text('Gemini API-Key', style: TextStyle(color: Colors.white)),
                          content: TextField(
                            controller: controller,
                            autofocus: true,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: 'Gemini API-Key hier einfügen',
                              hintStyle: TextStyle(color: Color(0xFF6E7681)),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Abbrechen'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                _saveGeminiKey(controller.text.trim());
                                Navigator.pop(ctx);
                              },
                              child: const Text('Speichern'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Key ändern'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Key holen: aistudio.google.com/app/apikey (kostenlos)',
            style: TextStyle(color: Color(0xFF6E7681), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _ruleCard(String title, String body, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF58A6FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
