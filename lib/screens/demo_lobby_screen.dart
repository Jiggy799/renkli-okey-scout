// lib/screens/demo_lobby_screen.dart
// RenkliOkeyScout — Demo Lobby: choose 1 or 2 players

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';
import 'demo_active_round_screen.dart';

class DemoLobbyScreen extends StatelessWidget {
  const DemoLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Demo Modus', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.science,
                size: 64,
                color: Color(0xFFF0C000),
              ),
              const SizedBox(height: 16),
              const Text(
                'Demo Modus',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Teste die App-Logik ohne echte Spieler.\nKI-Spieler übernehmen automatisch.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
              ),
              const SizedBox(height: 40),

              // 1-Spieler Karte
              _ModeCard(
                icon: Icons.person,
                title: '1 Spieler',
                subtitle: 'Du spielst allein mit 3 KI-Spielern.\nTeste alle Screens und Regeln.',
                color: const Color(0xFF58A6FF),
                onTap: () {
                  DemoState().init1Player();
                  context.go('/demo-setup');
                },
              ),

              const SizedBox(height: 16),

              // 2-Spieler Karte
              _ModeCard(
                icon: Icons.people,
                title: '2 Spieler',
                subtitle: 'Du + 1 Freund, mit 2 KI-Spielern.\nÇifte + Joker-Logik testen.',
                color: const Color(0xFF238636),
                onTap: () {
                  DemoState().init2Players();
                  context.go('/demo-setup');
                },
              ),

              const Spacer(),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFFF0C000), size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Was wird getestet?',
                          style: TextStyle(
                            color: Color(0xFFF0C000),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '✓ Runden-System (11 Runden)\n'
                      '✓ Farb-Multiplikatoren (×2 bis ×5)\n'
                      '✓ Joker ×2 / Çifte ×2 / Joker+Çifte ×4\n'
                      '✓ Gösterme System B (-20 bis -50)\n'
                      '✓ Strafpunkte berechnen\n'
                      '✓ Spielende + Ergebnisanzeige',
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}
