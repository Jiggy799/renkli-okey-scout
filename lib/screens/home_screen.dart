// lib/screens/home_screen.dart
// RenkliOkeyScout — Home Screen (EINFACH + KLAR)
//
// ZWEI grosse Buttons:
// 1. DEMO MODUS — Komplett offline, ohne Supabase
// 2. ONLINE SPIELEN — Mit Freunden, erfordert Anmeldung
//
// Plus: Settings, Regelwerk, Logout

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

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'RenkliOkeyScout',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book, color: Colors.white),
            tooltip: 'Regelwerk',
            onPressed: () => context.push('/rules'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Einstellungen',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── WELCOME ───
              const SizedBox(height: 20),
              const Text(
                'OKEY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hallo ${auth.displayName}!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // ─── DEMO MODUS (gross) ───
              _ModeCard(
                title: 'DEMO-MODUS',
                subtitle: 'Lokal testen\nKein Internet nötig',
                icon: Icons.science,
                color: const Color(0xFFF0C000),
                onTap: () => context.go('/demo-lobby'),
              ),

              const SizedBox(height: 16),

              // ─── ONLINE MODUS (gross) ───
              _ModeCard(
                title: 'ONLINE SPIELEN',
                subtitle: 'Tisch erstellen oder joinen\n4 Spieler gleichzeitig',
                icon: Icons.group,
                color: const Color(0xFF238636),
                onTap: () => context.go('/lobby'),
              ),

              const SizedBox(height: 32),

              // ─── USER INFO ───
              if (user != null)
                _UserInfoCard(user: user, auth: auth)
              else
                const Text(
                  'Nicht angemeldet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6E7681), fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MODE CARD ────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: color, size: 24),
          ],
        ),
      ),
    );
  }
}

// ─── USER INFO CARD ───────────────────────────────────────────────────────────

class _UserInfoCard extends StatelessWidget {
  final User user;
  final AuthService auth;

  const _UserInfoCard({required this.user, required this.auth});

  @override
  Widget build(BuildContext context) {
    final isAnonymous = user.isAnonymous;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnonymous
              ? const Color(0xFFF0C000)
              : const Color(0xFF3FB950),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isAnonymous
                  ? const Color(0xFFF0C000)
                  : const Color(0xFF3FB950),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                auth.displayName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auth.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isAnonymous ? 'Anonymer Account' : 'Mit Google angemeldet',
                  style: TextStyle(
                    color: isAnonymous
                        ? const Color(0xFFF0C000)
                        : const Color(0xFF3FB950),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF8B949E), size: 20),
            tooltip: 'Abmelden',
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
