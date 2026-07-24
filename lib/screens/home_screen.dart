// lib/screens/home_screen.dart
// RenkliOkeyScout — Home: Willkommen + Aktionen
//
// Username + Avatar kommen automatisch vom Provider (Google/Anonymous).
// Kein manuelles Username-Feld mehr.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final user = auth.currentUser;
    final name = auth.displayName;
    final avatar = auth.avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        actions: [
          // Logout
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E)),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),

                // User-Bereich: Avatar + Name
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF238636),
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.isAnonymous == true
                                  ? '👤 Anonymer Spieler'
                                  : '🔐 Angemeldet',
                              style: const TextStyle(
                                color: Color(0xFF8B949E),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildLogo(),
                const SizedBox(height: 8),
                const Text(
                  'RenkliOkeyScout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Okey Score Tracker',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Online-Modus Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/lobby'),
                    icon: const Icon(Icons.people, color: Colors.white),
                    label: const Text(
                      'Online spielen (Multiplayer)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Demo Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/demo-lobby'),
                    icon: const Icon(Icons.science, color: Color(0xFFF0C000)),
                    label: const Text(
                      'Demo-Modus (lokal testen)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF0C000),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF0C000)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Regelwerk
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () => context.push('/rules'),
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

                const SizedBox(height: 8),

                // Trainingsdaten sammeln
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/collect'),
                    icon: const Icon(Icons.science, size: 16, color: Color(0xFF58A6FF)),
                    label: const Text(
                      'Trainingsdaten sammeln (Beta)',
                      style: TextStyle(fontSize: 13, color: Color(0xFF58A6FF)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF58A6FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

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
                const SizedBox(height: 24),
              ],
            ),
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
          Positioned(
            left: 0,
            child: _tile(const Color(0xFFF0C000), '8', 34),
          ),
          Positioned(
            left: 26,
            child: _tile(const Color(0xFF1F6FEB), '13', 34),
          ),
          Positioned(
            left: 52,
            child: _tile(const Color(0xFFDA3633), '7', 34),
          ),
          Positioned(
            left: 78,
            child: _tile(const Color(0xFF6E7681), '3', 34),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: color == const Color(0xFFF0C000) || color == const Color(0xFF6E7681)
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
