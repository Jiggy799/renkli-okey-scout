// lib/screens/demo_round_setup_screen.dart
// Demo: Gösterge & Farbe VOR jeder Runde definieren
//
// FLOW:
// 1. Spieler X wählt Gösterge (Farbe + Nummer)
// 2. Andere Spieler müssen bestätigen (mind. 2 von 4)
// 3. Nach 2 Bestätigungen ist der Gösterge GELOCKT
// 4. Start-Button wird aktiv

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
  bool get _isLocked => _demo.isGostergeLocked;

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

  // Der Spieler der gerade "am Zug" ist (für Confirm-UI)
  String? _activeConfirmer;

  void _onConfirm(String playerId) {
    setState(() {
      _demo.confirmGosterge(playerId);
      _activeConfirmer = null;
    });
  }

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
              Text(
                _isLocked
                    ? '✓ Gösterge fixiert — kann nicht mehr geändert werden'
                    : 'Welcher Stein wurde gezogen?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isLocked ? const Color(0xFF3FB950) : const Color(0xFF8B949E),
                  fontSize: 13,
                  fontWeight: _isLocked ? FontWeight.bold : FontWeight.normal,
                ),
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
              const SizedBox(height: 8),

              // Lock indicator
              if (_isLocked)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: Color(0xFF3FB950), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Gösterge fixiert',
                        style: TextStyle(color: Color(0xFF3FB950), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Farbe wählen — DEAKTIVIERT wenn locked
              Opacity(
                opacity: _isLocked ? 0.4 : 1.0,
                child: IgnorePointer(
                  ignoring: _isLocked,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      // Nummer wählen — DEAKTIVIERT wenn locked
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
                              onPressed: _isLocked ? null : () => setState(() {
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
                              onPressed: _isLocked ? null : () => setState(() {
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
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ─── CONFIRM SECTION ────────────────────────────────────────────
              if (!_isLocked) _buildConfirmSection() else _buildLockedSection(),

              const Spacer(),

              // Start button — NUR aktiv wenn locked und ≥ 2 Bestätigungen
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLocked
                      ? () {
                          for (final p in _demo.players) {
                            p.penaltyBasis = 0;
                            p.isCifte = false;
                            p.photoSubmitted = false;
                          }
                          _demo.winType = WinType.normal;
                          _demo.gostergeShownBy = null;
                          context.go('/demo-round');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _tableColorColor,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFF30363D),
                    disabledForegroundColor: const Color(0xFF6E7681),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isLocked ? 'Runde starten' : 'Noch ${2 - _demo.gostergeConfirmedBy.length} Bestätigung${2 - _demo.gostergeConfirmedBy.length == 1 ? '' : 'en'} nötig',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Confirm Section (Vor dem Lock) ──────────────────────────────────────

  Widget _buildConfirmSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0C000), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFFF0C000), size: 18),
              SizedBox(width: 8),
              Text(
                'Bestätigung nötig',
                style: TextStyle(color: Color(0xFFF0C000), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mind. 2 Spieler müssen den Gösterge bestätigen.',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
          const SizedBox(height: 12),
          // Spieler die schon bestätigt haben
          if (_demo.gostergeConfirmers.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _demo.gostergeConfirmers.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3FB950).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3FB950)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Color(0xFF3FB950), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      p.name,
                      style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11),
                    ),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          // "Jetzt bestätigen" Dropdown
          DropdownButton<String>(
            value: _activeConfirmer,
            isExpanded: true,
            hint: const Text(
              'Spieler wählt: "Ich bestätige"',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
            dropdownColor: const Color(0xFF161B22),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: _demo.players
                .where((p) => !_demo.gostergeConfirmedBy.contains(p.id))
                .map((p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) _onConfirm(v);
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${_demo.gostergeConfirmedBy.length} / 2 Bestätigungen',
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ─── Locked Section (Nach 2 Bestätigungen) ──────────────────────────────

  Widget _buildLockedSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3FB950).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3FB950), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF3FB950), size: 18),
              SizedBox(width: 8),
              Text(
                'Gösterge fixiert',
                style: TextStyle(color: Color(0xFF3FB950), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bestätigt von:',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _demo.gostergeConfirmers.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3FB950).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, color: Color(0xFF3FB950), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    p.name,
                    style: const TextStyle(color: Color(0xFF3FB950), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Helpers (von alt übernommen) ────────────────────────────────────────

  Widget _tileDisplay(TileColor color, int number, String label) {
    final col = _tileColor(color);
    return Column(
      children: [
        Opacity(
          opacity: _isLocked ? 0.7 : 1.0,
          child: Container(
            width: 64,
            height: 64 * 1.35,
            decoration: BoxDecoration(
              color: col,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isLocked ? const Color(0xFF3FB950) : Colors.white.withValues(alpha: 0.2),
                width: _isLocked ? 2.5 : 1.5,
              ),
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
