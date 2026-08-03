// lib/screens/demo_round_setup_screen.dart
// Demo: Gösterge & Farbe VOR jeder Runde definieren
//
// FLOW (OPTIONAL - kann komplett übersprungen werden):
// 1. Spieler wählt Gösterge (Farbe + Nummer)
// 2. Frage pro Spieler: "Hast du den Gösterge?" → Ja/Nein
// 3. Wenn mindestens 1 Spieler "Ja" sagt → Bonus für diesen
// 4. Wenn niemand "Ja" sagt → kein Bonus, trotzdem Runde starten
//
// Die Confirm-Logik ist OPTIONAL — die App ist nur ein Zähl-Helfer.

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

  TileColor get _selectedColor => _demo.selectedColor;
  int get _gostergeNumber => _demo.gostergeNumber;

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  int get _jokerNumber {
    int j = _gostergeNumber + 1;
    if (j > 13) j = 1;
    return j;
  }

  Color get _tableColorColor => _tileColor(_selectedColor);

  // Welcher Spieler wird gerade gefragt (für "Wer hat den Gösterge?" UI)
  String? _askingPlayer;

  void _onResponse(String playerId, bool hasIt) {
    setState(() {
      _demo.setGostergeResponse(playerId, hasIt: hasIt);
      _askingPlayer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bonus = _demo.gostergeIsConfirmed
        ? berechneGostermeBonus(_selectedColor)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${_demo.currentRound}/11 · Setup',
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
              // Header
              const Text(
                'Gösterge definieren',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcher Stein wurde gezogen?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Gösterge + Joker tiles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _tileDisplay(_selectedColor, _gostergeNumber, 'GÖSTERGE'),
                  const SizedBox(width: 24),
                  Icon(Icons.arrow_forward, color: _tableColorColor.withValues(alpha: 0.5), size: 20),
                  const SizedBox(width: 24),
                  _tileDisplay(_selectedColor, _jokerNumber, 'JOKER'),
                ],
              ),
              const SizedBox(height: 24),

              // Farbe wählen
              const Text(
                'Tischfarbe',
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
              const SizedBox(height: 16),

              // Nummer wählen
              const Text(
                'Gösterge-Nummer',
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
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, color: _tableColorColor),
                      onPressed: () => setState(() {
                        _demo.gostergeNumber = _demo.gostergeNumber > 1 ? _demo.gostergeNumber - 1 : 13;
                      }),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$_gostergeNumber',
                          style: TextStyle(
                            color: _tableColorColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add, color: _tableColorColor),
                      onPressed: () => setState(() {
                        _demo.gostergeNumber = _demo.gostergeNumber < 13 ? _demo.gostergeNumber + 1 : 1;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Joker: ${_selectedColor.name[0].toUpperCase()}$_jokerNumber',
                  style: TextStyle(color: _tableColorColor, fontSize: 12),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: Color(0xFF30363D)),
              const SizedBox(height: 16),

              // ─── Gösterge-Confirm Section (OPTIONAL) ─────────────────────
              _buildConfirmSection(bonus),

              const SizedBox(height: 24),

              // Start button — IMMER aktiv (kein Lock-Zwang mehr)
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    for (final p in _demo.players) {
                      p.schrottTiles = [];
                      p.isCifte = false;
                      p.photoSubmitted = false;
                    }
                    _demo.winType = WinType.normal;

                    // Bonus an Holder geben, falls bestätigt
                    final holder = _demo.gostergeConfirmedHolder;
                    if (holder != null) {
                      _demo.applyGostermeTo(holder);
                    } else {
                      _demo.gostergeShownBy = null;
                    }

                    context.go('/demo-round');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tableColorColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Runde starten',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Tipp: Gösterge-Confirm ist optional',
                  style: TextStyle(color: Color(0xFF6E7681), fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmSection(int? bonus) {
    final bonusText = bonus != null
        ? 'Bonus: $bonus Punkte für den Halter'
        : 'Noch kein Halter bestätigt';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bonus != null ? const Color(0xFF3FB950) : const Color(0xFF30363D),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                bonus != null ? Icons.check_circle : Icons.help_outline,
                color: bonus != null ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Wer hat den Gösterge?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_demo.hasAnyGostergeResponse)
                TextButton(
                  onPressed: () => setState(() => _demo.resetGostergeConfirmations()),
                  child: const Text('Reset', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            bonusText,
            style: TextStyle(
              color: bonus != null ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Status pro Spieler
          ..._demo.players.map((p) {
            final response = _demo.gostergeConfirmations[p.id];
            final hasResponded = response != null;
            final hasIt = response == true;

            Color bgColor;
            IconData icon;
            String label;

            if (!hasResponded) {
              bgColor = const Color(0xFF21262D);
              icon = Icons.help_outline;
              label = 'Noch nicht gefragt';
            } else if (hasIt) {
              bgColor = const Color(0xFF3FB950).withValues(alpha: 0.2);
              icon = Icons.check;
              label = '✓ Hat Gösterge!';
            } else {
              bgColor = const Color(0xFFDA3633).withValues(alpha: 0.15);
              icon = Icons.close;
              label = 'Hat ihn nicht';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: hasResponded
                        ? (hasIt ? const Color(0xFF3FB950) : const Color(0xFFF85149))
                        : const Color(0xFF8B949E), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.name}  •  $label',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: hasIt ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (!hasResponded)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => _onResponse(p.id, true),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text('Ja', style: TextStyle(color: Color(0xFF3FB950))),
                          ),
                          TextButton(
                            onPressed: () => _onResponse(p.id, false),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 0),
                            ),
                            child: const Text('Nein', style: TextStyle(color: Color(0xFFF85149))),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _tileDisplay(TileColor color, int number, String label) {
    final col = _tileColor(color);
    return Column(
      children: [
        Container(
          width: 60,
          height: 60 * 1.35,
          decoration: BoxDecoration(
            color: col,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: col.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: color == TileColor.yellow || color == TileColor.black
                    ? Colors.black
                    : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: col,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _colorBtn(TileColor color, String name, String mult) {
    final isSelected = _selectedColor == color;
    final col = _tileColor(color);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _demo.selectedColor = color),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                mult,
                style: TextStyle(
                  color: isSelected ? Colors.white : col,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Demo verlassen?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ungespeicherte Daten gehen verloren.',
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
            child: const Text('Verlassen'),
          ),
        ],
      ),
    );
  }
}