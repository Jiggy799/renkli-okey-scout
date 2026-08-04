// lib/screens/demo_round_setup_screen.dart
// RenkliOkeyScout — Demo Round Setup
//
// EIN-FÜR-ALLEMAL: Tischfarbe + Gösterge-Nummer wählen
// KEINE fragwürdigen Bestätigungen, KEINE Bonus-Popups
// Spieler-Stats werden PRO Runde sichtbar

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';

class DemoRoundSetupScreen extends StatefulWidget {
  const DemoRoundSetupScreen({super.key});

  @override
  State<DemoRoundSetupScreen> createState() => _DemoRoundSetupScreenState();
}

class _DemoRoundSetupScreenState extends State<DemoRoundSetupScreen> {
  final _demo = DemoState();

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  Color get _tableColorColor => _tileColor(_demo.selectedColor);

  int get _jokerNumber {
    int j = _demo.gostergeNumber + 1;
    if (j > 13) j = 1;
    return j;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${_demo.currentRound} / 11',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _showExitDialog(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── HEADER ───
              const Text(
                'Runde einrichten',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Wer hat gewonnen? Tischfarbe? Gösterge?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 24),

              // ─── GEWINNER-AUSWAHL (nur 1!) ───
              const Text(
                '1. Wer hat gewonnen?',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ..._demo.players.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  onTap: () => setState(() {
                    // SINGLE-WINNER: alle anderen zurücksetzen
                    for (final other in _demo.players) {
                      other.isWinner = (other.id == p.id);
                    }
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.isWinner
                          ? const Color(0xFF3FB950).withValues(alpha: 0.2)
                          : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: p.isWinner
                            ? const Color(0xFF3FB950)
                            : const Color(0xFF30363D),
                        width: p.isWinner ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          p.isWinner ? Icons.emoji_events : Icons.person_outline,
                          color: p.isWinner ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          p.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: p.isWinner ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const Spacer(),
                        if (p.isWinner)
                          const Text(
                            'Gewinner',
                            style: TextStyle(color: Color(0xFF3FB950), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 24),

              // ─── TISCHFARBE ───
              const Text(
                '2. Tischfarbe (× Multiplikator)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _colorBtn(TileColor.yellow, 'Gelb', '×2'),
                  const SizedBox(width: 8),
                  _colorBtn(TileColor.blue, 'Blau', '×3'),
                  const SizedBox(width: 8),
                  _colorBtn(TileColor.red, 'Rot', '×4'),
                  const SizedBox(width: 8),
                  _colorBtn(TileColor.black, 'Schwarz', '×5'),
                ],
              ),
              const SizedBox(height: 24),

              // ─── GÖSTERGE-NUMMER ───
              const Text(
                '3. Gösterge-Nummer (welcher Stein wurde aufgedeckt?)',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _tableColorColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: _tableColorColor, size: 28),
                      onPressed: () => setState(() {
                        _demo.gostergeNumber = _demo.gostergeNumber > 1 ? _demo.gostergeNumber - 1 : 13;
                      }),
                    ),
                    SizedBox(
                      width: 60,
                      child: Center(
                        child: Text(
                          '${_demo.gostergeNumber}',
                          style: TextStyle(
                            color: _tableColorColor,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: _tableColorColor, size: 28),
                      onPressed: () => setState(() {
                        _demo.gostergeNumber = _demo.gostergeNumber < 13 ? _demo.gostergeNumber + 1 : 1;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Gösterge: ${_demo.selectedColor.name.toUpperCase()} ${_demo.gostergeNumber}  →  Joker: ${_demo.selectedColor.name.toUpperCase()} $_jokerNumber',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                ),
              ),
              const SizedBox(height: 24),

              // ─── ÇIFTE ───
              const Text(
                '4. Çifte (5/7-Paare)?',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _cifteBtn(false, 'Nein', 'Normaler Finish'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _cifteBtn(true, 'Ja', '5 Paare + Reihe'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ─── START BUTTON ───
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // WINNER-CHECK: kein Gewinner → erlauben, oder blockieren?
                    // Strategie: KEIN Gewinner = Runde ist "alle verloren"
                    // (selten, aber möglich bei Server-Stapel leer)
                    _demo.winType = WinType.normal; // wird im active round pro spieler überschrieben
                    for (final p in _demo.players) {
                      p.schrottTiles = [];
                      p.isCifte = false;
                      p.isJokerFinish = false;
                      p.photoSubmitted = false;
                    }
                    _demo.gostergeShownBy = null;
                    context.go('/demo-round');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Runde starten',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ─── ABORT ───
              TextButton(
                onPressed: () => _showExitDialog(),
                child: const Text(
                  'Spiel beenden',
                  style: TextStyle(color: Color(0xFF6E7681)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorBtn(TileColor color, String name, String mult) {
    final isSelected = _demo.selectedColor == color;
    final col = _tileColor(color);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _demo.selectedColor = color),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? col : col.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? Border.all(color: Colors.white, width: 2) : Border.all(color: col.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? Colors.white : col,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mult,
                style: TextStyle(
                  color: isSelected ? Colors.white : col,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cifteBtn(bool isCifte, String title, String subtitle) {
    final isSelected = _demo.winType == WinType.cifte || _demo.winType == WinType.okeyCifte;
    final target = isCifte;
    return InkWell(
      onTap: () => setState(() {
        _demo.winType = target ? WinType.cifte : WinType.normal;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected == target
              ? const Color(0xFF1F6FEB).withValues(alpha: 0.2)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected == target
                ? const Color(0xFF1F6FEB)
                : const Color(0xFF30363D),
            width: isSelected == target ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Spiel beenden?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Alle Runden-Daten gehen verloren.',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _demo.reset();
              context.go('/');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDA3633)),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
  }
}
