// lib/screens/demo_active_round_screen.dart
// RenkliOkeyScout — Active Round (ANTI-CHEAT + praktisch)
//
// ANTI-CHEAT DESIGN:
//   - Gewinner ist GLOBAL — kann nicht pro Spieler geändert werden
//   - Joker ×2 ist GLOBAL — gilt für alle Verlierer
//   - Pro Spieler: NUR Schrott-Steine wählen + Foto machen
//   - Mini-Tiles zeigen erkannte Steine
//   - X-Button zum Korrigieren (wenn Erkennung falsch)
//
// FLOW:
//   1. Pro Spieler: "Foto machen" → App klassifiziert (Stub)
//   2. Pro Spieler: SnackBar "4 Steine erkannt (Summe: 47)"
//   3. User kann falsche Steine X-en
//   4. User kann zusätzliche Steine hinzufügen (wenn übersehen)
//   5. "Runde auswerten" → Result

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';

class DemoActiveRoundScreen extends StatefulWidget {
  const DemoActiveRoundScreen({super.key});

  @override
  State<DemoActiveRoundScreen> createState() => _DemoActiveRoundScreenState();
}

class _DemoActiveRoundScreenState extends State<DemoActiveRoundScreen> {
  final _demo = DemoState();
  final _picker = ImagePicker();

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tischColor = _tileColor(_demo.selectedColor);
    final gosterge = _demo.currentGostergeTile;
    final joker = _demo.currentJokerTile;
    final isJokerRound = joker == gosterge; // Sonderfall: gosterge == joker

    final winner = _demo.players.firstWhere(
      (p) => p.isWinner,
      orElse: () => DemoPlayer(id: '_none', name: '—', seatIndex: -1),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${_demo.currentRound} / 11',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── HEADER (kompakt) ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF161B22),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: tischColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Tisch: ${_demo.selectedColor.name.toUpperCase()} × ${_demo.tableFactor}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Gösterge: ${gosterge.color.name.toUpperCase()} ${gosterge.number}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '→ Joker: ${joker.color.name.toUpperCase()} ${joker.number}',
                    style: TextStyle(
                      color: isJokerRound ? const Color(0xFF8957E5) : const Color(0xFF8B949E),
                      fontSize: 11,
                      fontWeight: isJokerRound ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (winner.id != '_none')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3FB950).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFF3FB950), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            winner.name,
                            style: const TextStyle(color: Color(0xFF3FB950), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ─── SPIELER-LISTE ───
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _demo.players.length,
                itemBuilder: (ctx, i) => _PlayerCard(
                  player: _demo.players[i],
                  tileColor: _tileColor,
                  onTakePhoto: () => _takePhotoAndClassify(_demo.players[i]),
                  demo: _demo,
                  onRemoveTile: (tile) => setState(() => _demo.players[i].schrottTiles.remove(tile)),
                  onAddTile: (tile) => setState(() => _demo.players[i].schrottTiles.add(tile)),
                ),
              ),
            ),

            // ─── BOTTOM BAR ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF161B22),
                border: Border(top: BorderSide(color: Color(0xFF30363D))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryChip(
                        label: 'Σ Schrott',
                        value: '${_demo.players.fold(0, (s, p) => s + p.schrottSum)}',
                        color: const Color(0xFFF0C000),
                      ),
                      _SummaryChip(
                        label: 'Σ Strafpunkte',
                        value: '${_demo.players.fold(0, (s, p) => s + _demo.calculatePenalty(p))}',
                        color: const Color(0xFFDA3633),
                      ),
                      _SummaryChip(
                        label: 'Gösterge',
                        value: _demo.gostergeShownBy != null
                            ? _demo.players.firstWhere((p) => p.id == _demo.gostergeShownBy).name
                            : '—',
                        color: const Color(0xFFF0C000),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.go('/demo-round-result'),
                      child: const Text(
                        'Runde auswerten',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhotoAndClassify(DemoPlayer player) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (photo == null) return;

      setState(() {
        player.photoSubmitted = true;
        // HEURISTIK (Stub): 4-8 zufällige Schrott-Steine
        final rng = DateTime.now().millisecondsSinceEpoch;
        final numTiles = 4 + (rng % 5);
        final tiles = <Tile>[];
        for (int i = 0; i < numTiles; i++) {
          final c = TileColor.values[(rng + i * 3) % 4];
          final n = 1 + ((rng + i * 7) % 13);
          tiles.add(Tile(c, n));
        }
        player.schrottTiles = tiles;
      });

      if (mounted) {
        final sum = player.schrottSum;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ ${player.schrottTiles.length} Steine erkannt (Summe: $sum)',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF3FB950),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto fehlgeschlagen: $e'),
            backgroundColor: const Color(0xFFDA3633),
          ),
        );
      }
    }
  }
}

// ─── PLAYER CARD (Mit TilePickerSheet für Korrektur) ─────────────────────────

class _PlayerCard extends StatelessWidget {
  final DemoPlayer player;
  final DemoState demo;
  final Color Function(TileColor) tileColor;
  final VoidCallback onTakePhoto;
  final void Function(Tile) onRemoveTile;
  final void Function(Tile) onAddTile;

  const _PlayerCard({
    required this.player,
    required this.demo,
    required this.tileColor,
    required this.onTakePhoto,
    required this.onRemoveTile,
    required this.onAddTile,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = player.schrottTiles;
    final sum = player.schrottSum;
    final penalty = demo.calculatePenalty(player);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: player.isWinner
              ? const Color(0xFF3FB950)
              : const Color(0xFF30363D),
          width: player.isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── ZEILE 1: Name + Status ───
          Row(
            children: [
              if (player.isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.emoji_events, color: Color(0xFF3FB950), size: 18),
                ),
              Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (player.photoSubmitted)
                const Icon(Icons.photo_camera, color: Color(0xFF3FB950), size: 16),
            ],
          ),

          const SizedBox(height: 10),

          // ─── ZEILE 2: Foto-Button (oder erkannte Steine) ───
          if (tiles.isEmpty)
            OutlinedButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text(
                'Foto machen → Schrott-Steine erkennen',
                style: TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F6FEB),
                side: const BorderSide(color: Color(0xFF1F6FEB)),
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Erkannte Steine
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1117),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tiles.map((t) => _MiniTile(
                      tile: t,
                      color: tileColor(t.color),
                      onRemove: () => onRemoveTile(t),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onTakePhoto,
                        icon: const Icon(Icons.photo_camera, size: 14),
                        label: const Text('Neues Foto', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1F6FEB),
                          side: const BorderSide(color: Color(0xFF1F6FEB)),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showAddTileSheet(context),
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Stein +', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF0C000),
                          side: const BorderSide(color: Color(0xFFF0C000)),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 10),

          // ─── ZEILE 3: Gösterge-BUTTON (kann nur einmal gesetzt werden) ───
          if (demo.gostergeShownBy == null)
            OutlinedButton.icon(
              onPressed: () {
                // Set Gösterge for this player
                // (nur sinnvoll wenn Spieler tatsächlich den Gösterge hat)
                // Hier vereinfacht: User entscheidet wer ihn hat
              },
              icon: const Icon(Icons.local_fire_department, size: 14),
              label: const Text('Gösterge zeigen (−50)', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF0C000),
                side: const BorderSide(color: Color(0xFFF0C000)),
                minimumSize: const Size(double.infinity, 32),
              ),
            )
          else if (demo.gostergeShownBy == player.id)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0C000).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF0C000)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Color(0xFFF0C000), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Gösterge: ${demo.berechneGostermeBonus(demo.selectedColor)} Bonus',
                    style: const TextStyle(color: Color(0xFFF0C000), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // ─── ZEILE 4: Vorschau (READ-ONLY — Anti-Cheat) ───
          const Divider(color: Color(0xFF30363D), height: 16),
          Row(
            children: [
              const Text(
                'Strafpunkte:',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              const Spacer(),
              Text(
                tiles.isEmpty
                    ? '—'
                    : '$sum × ${demo.tableFactor} = ',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
              ),
              Text(
                tiles.isEmpty ? '—' : '$penalty',
                style: TextStyle(
                  color: tiles.isEmpty ? const Color(0xFF8B949E) : const Color(0xFFDA3633),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AddTileSheet(
        onAdd: (tile) => onAddTile(tile),
        tileColor: tileColor,
      ),
    );
  }
}

// ─── ADD TILE SHEET (4×13 Grid zum manuellen Hinzufügen) ─────────────────────

class _AddTileSheet extends StatefulWidget {
  final void Function(Tile) onAdd;
  final Color Function(TileColor) tileColor;
  const _AddTileSheet({required this.onAdd, required this.tileColor});

  @override
  State<_AddTileSheet> createState() => _AddTileSheetState();
}

class _AddTileSheetState extends State<_AddTileSheet> {
  TileColor? _selectedColor;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stein hinzufügen',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Wenn die Foto-Erkennung einen Stein übersehen hat.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
            const SizedBox(height: 16),
            // Farbe wählen
            Row(
              children: TileColor.values.map((c) {
                final isSelected = _selectedColor == c;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? widget.tileColor(c) : widget.tileColor(c).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: widget.tileColor(c)),
                        ),
                        child: Text(
                          c.name.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : widget.tileColor(c),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Zahlen 1-13
            if (_selectedColor != null)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(13, (i) => i + 1).map((n) {
                  return InkWell(
                    onTap: () {
                      widget.onAdd(Tile(_selectedColor!, n));
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.tileColor(_selectedColor!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: _selectedColor == TileColor.yellow || _selectedColor == TileColor.black
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── HILFS-WIDGETS ────────────────────────────────────────────────────────────

class _MiniTile extends StatelessWidget {
  final Tile tile;
  final Color color;
  final VoidCallback onRemove;
  const _MiniTile({required this.tile, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isYellow = tile.color == TileColor.yellow;
    final isBlack = tile.color == TileColor.black;
    final textColor = (isYellow || isBlack) ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${tile.color.name[0].toUpperCase()}${tile.number}',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: Icon(Icons.close, color: textColor, size: 12),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
