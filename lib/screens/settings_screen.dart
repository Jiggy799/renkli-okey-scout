// lib/screens/settings_screen.dart
// RenkliOkeyScout — Settings / Profile screen

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _username;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

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

          // App info
          const Center(
            child: Text(
              'RenkliOkeyScout v1.0.0',
              style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
            ),
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
