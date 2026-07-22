// lib/screens/demo_active_round_screen.dart
// RenkliOkeyScout — Demo Active Round Screen (no Supabase)
// Tests: player list, Çifte toggle, Gösterme, penalty entry, round flow

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';
import 'demo_round_result_screen.dart';
import 'demo_game_over_screen.dart';

class DemoActiveRoundScreen extends StatefulWidget {
  const DemoActiveRoundScreen({super.key});

  @override
  State<DemoActiveRoundScreen> createState() => _DemoActiveRoundScreenState();
}

class _DemoActiveRoundScreenState extends State<DemoActiveRoundScreen> {
  final _demo = DemoState();
  String? _editingBasisFor; // player id being edited

  @override
  void initState() {
    super.initState();
    _demo.simulateAIPenalties();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  TileColor get _selectedColor => _demo.selectedColor;
  int get _gostergeNumber => _demo.gostergeNumber;
  Tile get _gostergeTile => _demo.currentGostergeTile;
  Tile get _jokerTile => _demo.currentJokerTile;

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  Color get _tableColorColor => _tileColor(_selectedColor);
  int get _tableFactor => _demo.tableFactor;

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _toggleCifte(String playerId) {
    setState(() {
      final p = _demo.players.firstWhere((pl) => pl.id == playerId);
      p.isCifte = !p.isCifte;
    });
  }

  void _applyGosterme(String playerId) {
    setState(() {
      _demo.applyGostermeTo(playerId);
    });
  }

  void _showPenaltyDialog(DemoPlayer p) {
    if (p.isHuman) {
      setState(() => _editingBasisFor = p.id);
      _penaltyDialog(p);
    }
  }

  void _penaltyDialog(DemoPlayer p) {
    final controller = TextEditingController(
      text: p.penaltyBasis > 0 ? '${p.penaltyBasis}' : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          '${p.name} — Strafpunkte',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Steine-Summe eingeben (Zahl auf Brett, nicht multipliziert)',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              textAlign: TextAlign.center,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'z.B. 12',
                hintStyle: const TextStyle(color: Color(0xFF30363D)),
                filled: true,
                fillColor: const Color(0xFF0D1117),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _tableColorColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _tableColorColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tableColorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _tableColorColor),
              ),
              child: Column(
                children: [
                  Text(
                    'Faktor: ×$_tableFactor',
                    style: TextStyle(color: _tableColorColor, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.name}: ×${_demo.liveFactorFor(p)} = ? Punkte',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen', style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text.trim()) ?? 0;
              setState(() {
                p.penaltyBasis = val;
                _editingBasisFor = null;
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _tableColorColor,
              foregroundColor: Colors.black,
            ),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _endRound() {
    // AI penalties already simulated in _showPhotoDialog
    _demo.applyRoundEnd();

    if (_demo.isGameOver) {
      context.go('/demo-gameover');
    } else {
      context.go('/demo-round-result');
    }
  }

  void _showPhotoDialog() {
    // Simulate AI penalties before photo step
    _demo.simulateAIPenalties();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Row(
            children: [
              Icon(Icons.camera_alt, color: Color(0xFFF0C000)),
              const SizedBox(width: 8),
              const Text('Foto-Pflicht',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Jeder Spieler muss ein Foto machen.\nFehlendes Foto = +100 Strafpunkte.',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const SizedBox(height: 16),
              ..._demo.players.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: _tableColorColor.withValues(alpha: 0.2),
                      child: Text('\${p.seatIndex + 1}',
                          style: TextStyle(color: _tableColorColor, fontSize: 11)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    if (p.photoSubmitted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color(0xFF238636).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Color(0xFF238636)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, color: Color(0xFF238636), size: 12),
                            const SizedBox(width: 4),
                            Text('Foto ✓',
                                style: TextStyle(color: Color(0xFF238636), fontSize: 11)),
                          ],
                        ),
                      )
                    else
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() => p.photoSubmitted = true);
                        },
                        icon: Icon(Icons.camera_alt, size: 14, color: Color(0xFFDA3633)),
                        label: Text('+100 P',
                            style: TextStyle(color: Color(0xFFDA3633), fontSize: 11)),
                      ),
                  ],
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zurück',
                  style: TextStyle(color: Color(0xFF8B949E))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _demo.applyRoundEnd();
                if (_demo.isGameOver) {
                  context.go('/demo-gameover');
                } else {
                  context.go('/demo-round-result');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF238636),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _demo.players.any((p) => !p.photoSubmitted)
                    ? 'Trotzdem weiter (\${_demo.players.where((p) => !p.photoSubmitted).length}× +100)'
                    : 'Weiter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndRoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Runde beenden?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Alle Strafpunkte werden eingetragen.\nKI-Spieler bekommen Zufalls-Werte.',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen',
                style: TextStyle(color: Color(0xFF8B949E))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPhotoDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            child: const Text('Weiter zu Foto'),
          ),
        ],
      ),
    );
  }


  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Demo · Runde ${_demo.currentRound}/11',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _showExitDialog(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: Color(0xFFF0C000)),
            onPressed: _showEndRoundDialog,
            tooltip: 'Runde beenden',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTableHeader(),
            _buildControlBar(),
            const Divider(color: Color(0xFF30363D), height: 1),
            Expanded(child: _buildPlayerList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: const Color(0xFF161B22),
      child: Column(
        children: [
          // Gösterge + Joker info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tileChip(_gostergeTile, 'GOSTERGE'),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, color: _tableColorColor.withValues(alpha: 0.5), size: 16),
              const SizedBox(width: 8),
              _tileChip(_jokerTile, 'JOKER'),
            ],
          ),
          const SizedBox(height: 12),
          // Color selectors
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _colorChip(TileColor.yellow, '×2'),
              const SizedBox(width: 8),
              _colorChip(TileColor.blue, '×3'),
              const SizedBox(width: 8),
              _colorChip(TileColor.red, '×4'),
              const SizedBox(width: 8),
              _colorChip(TileColor.black, '×5'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tileChip(Tile tile, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _tileColor(tile.color).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _tileColor(tile.color)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _tileColor(tile.color),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${tile.color.name[0].toUpperCase()}${tile.number}',
            style: TextStyle(
              color: _tileColor(tile.color),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorChip(TileColor color, String mult) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _demo.selectedColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _tileColor(color).withValues(alpha: isSelected ? 1.0 : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Center(
          child: Text(
            mult,
            style: TextStyle(
              color: isSelected ? Colors.white : _tileColor(color),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0D1117),
      child: Row(
        children: [
          const Text(
            'Okey atmak',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
          ),
          const SizedBox(width: 8),
          Switch(
            value: _demo.winType == WinType.okey || _demo.winType == WinType.okeyCifte,
            onChanged: (v) => setState(() {
              _demo.winType = v
                  ? (_demo.winType == WinType.cifte ? WinType.okeyCifte : WinType.okey)
                  : (_demo.winType == WinType.okeyCifte ? WinType.cifte : WinType.normal);
            }),
            activeThumbColor: const Color(0xFF58A6FF),
            activeTrackColor: const Color(0xFF58A6FF).withValues(alpha: 0.4),
          ),
          if (_demo.winType == WinType.okey || _demo.winType == WinType.okeyCifte)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '×2',
                style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _tableColorColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _tableColorColor, width: 1),
            ),
            child: Text(
              'Faktor ×$_tableFactor${_demo.winType == WinType.okey || _demo.winType == WinType.okeyCifte ? '×2' : ''}${_demo.winType == WinType.okeyCifte || _demo.winType == WinType.cifte ? '×2' : ''}',
              style: TextStyle(
                color: _tableColorColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _demo.players.length,
      itemBuilder: (ctx, i) => _playerCard(_demo.players[i]),
    );
  }

  Widget _playerCard(DemoPlayer p) {
    final isEditing = _editingBasisFor == p.id;
    final factor = _demo.liveFactorFor(p);
    final penalty = _demo.calculatePenalty(p);
    final bonus = _demo.gostergeBonusFor(p.id); // System B

    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: p.isHuman ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
          width: p.isHuman ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _tableColorColor.withValues(alpha: 0.2),
                  child: Text(
                    '${p.seatIndex + 1}',
                    style: TextStyle(color: _tableColorColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (p.isHuman) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'DU',
                                style: TextStyle(color: Color(0xFF58A6FF), fontSize: 9),
                              ),
                            ),
                          ],
                          if (!p.isHuman) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6E7681).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'KI',
                                style: TextStyle(color: Color(0xFF6E7681), fontSize: 9),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Strafpunkte: ${p.cumulativePenalty}${bonus > 0 ? ' −$bonus Bonus' : ''}',
                        style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tableColorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tableColorColor, width: 1),
                  ),
                  child: Text(
                    '×$factor',
                    style: TextStyle(color: _tableColorColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons row
            Row(
              children: [
                // Çifte button
                Expanded(
                  child: _ActionButton(
                    label: 'Çifte',
                    icon: Icons.compare_arrows,
                    isActive: p.isCifte,
                    activeColor: const Color(0xFFF0C000),
                    onTap: () => _toggleCifte(p.id),
                    subtitle: p.isCifte ? '×2' : 'aus',
                  ),
                ),
                const SizedBox(width: 8),

                // Gösterme button
                Expanded(
                  child: _ActionButton(
                    label: 'Gösterme',
                    icon: Icons.visibility,
                    isActive: _demo.gostergeShownBy == p.id,
                    activeColor: const Color(0xFF238636),
                    onTap: _demo.gostergeShownBy == p.id
                        ? null
                        : () => _applyGosterme(p.id),
                    subtitle: _demo.gostergeShownBy == p.id
                        ? '✓ +${berechneGostermeStrafe(_selectedColor)}'
                        : '(+${berechneGostermeStrafe(_selectedColor)})',
                  ),
                ),
                const SizedBox(width: 8),

                // Penalty entry
                Expanded(
                  child: GestureDetector(
                    onTap: p.isHuman ? () => _showPenaltyDialog(p) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isEditing ? _tableColorColor : const Color(0xFF30363D),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: p.isHuman
                                ? const Color(0xFF58A6FF)
                                : const Color(0xFF30363D),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.penaltyBasis > 0 ? '${p.penaltyBasis} Steine' : 'Strafe',
                            style: TextStyle(
                              color: p.isHuman
                                  ? const Color(0xFF58A6FF)
                                  : const Color(0xFF30363D),
                              fontSize: 10,
                            ),
                          ),
                          if (p.penaltyBasis > 0)
                            Text(
                              '=$penalty P',
                              style: TextStyle(
                                color: _tableColorColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  final String? subtitle;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.2)
              : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFF30363D),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isActive ? activeColor : const Color(0xFF8B949E)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : const Color(0xFF8B949E),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  color: (isActive ? activeColor : const Color(0xFF8B949E)).withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
