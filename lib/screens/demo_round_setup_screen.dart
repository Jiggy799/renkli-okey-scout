// lib/screens/demo_round_setup_screen.dart
// Demo: Gösterge & Farbe VOR jeder Runde definieren

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';
import 'demo_active_round_screen.dart';

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

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
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
                'Welcher Stein wurde gezogen? Das bestimmt die Tischfarbe & Joker.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 32),

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
              const SizedBox(height: 32),

              // Farbe wählen
              const Text(
                'Tischfarbe',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _colorBtn(TileColor.yellow, 'Gelb', '×2'),
                  const SizedBox(width: 10),
                  _colorBtn(TileColor.blue, 'Blau', '×3'),
                  const SizedBox(width: 10),
                  _colorBtn(TileColor.red, 'Rot', '×4'),
                  const SizedBox(width: 10),
                  _colorBtn(TileColor.black, 'Schwarz', '×5'),
                ],
              ),
              const SizedBox(height: 28),

              // Nummer wählen
              const Text(
                'Gösterge-Nummer',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            fontSize: 36,
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
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Joker: ${_selectedColor.name[0].toUpperCase()}$_jokerNumber',
                  style: TextStyle(color: _tableColorColor, fontSize: 13),
                ),
              ),

              const Spacer(),

              // Start button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // Reset per-round state before starting
                    for (final p in _demo.players) {
                      p.penaltyBasis = 0;
                      p.isCifte = false;
                      p.photoSubmitted = false;
                    }
                    _demo.winType = WinType.normal;
                    _demo.gostergeShownBy = null;
                    context.go('/demo-round');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tableColorColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Runde starten',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tileDisplay(TileColor color, int number, String label) {
    final col = _tileColor(color);
    return Column(
      children: [
        Container(
          width: 64,
          height: 64 * 1.35,
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
                fontSize: 28,
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
