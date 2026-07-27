// lib/screens/tutorial_screen.dart
// RenkliOkeyScout — Kurzes Tutorial beim ersten Start

import 'package:flutter/material.dart';

class TutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const TutorialScreen({super.key, required this.onComplete});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _pages = <_TPage>[
    _TPage(
      icon: Icons.play_arrow,
      title: 'Willkommen!',
      body: 'Diese App zählt Okey-Punkte für dich.\nDu brauchst kein Stift und Papier mehr.',
    ),
    _TPage(
      icon: Icons.science,
      title: 'Demo-Modus',
      body: 'Teste alles lokal ohne Freunde.\n\n1 oder 2 Spieler, 11 Runden.',
    ),
    _TPage(
      icon: Icons.people,
      title: 'Online spielen',
      body: 'Erstelle einen Tisch, scannen QR-Code,\nspiele mit bis zu 4 Freunden.',
    ),
    _TPage(
      icon: Icons.camera_alt,
      title: 'Foto-Pflicht',
      body: 'Jeder Spieler muss am Rundenende\nseine Steine fotografieren.\n\nKein Foto = +100 Strafpunkte.',
    ),
    _TPage(
      icon: Icons.lock,
      title: 'Gösterge 2-Confirm',
      body: 'Gösterge muss von 2 Spielern bestätigt\nwerden, bevor die Runde startet.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onComplete,
                child: const Text(
                  'Überspringen',
                  style: TextStyle(color: Color(0xFF8B949E)),
                ),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (ctx, i) => _buildPage(_pages[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _page == i
                        ? const Color(0xFF58A6FF)
                        : const Color(0xFF30363D),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Next Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _page < _pages.length - 1 ? 'Weiter' : 'Loslegen!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_TPage p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF161B22),
              border: Border.all(color: const Color(0xFF238636), width: 2),
            ),
            child: Icon(p.icon, color: const Color(0xFF3FB950), size: 60),
          ),
          const SizedBox(height: 32),
          Text(
            p.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            p.body,
            style: const TextStyle(
              color: Color(0xFFC9D1D9),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TPage {
  final IconData icon;
  final String title;
  final String body;
  const _TPage({required this.icon, required this.title, required this.body});
}