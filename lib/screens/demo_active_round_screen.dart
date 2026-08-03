// lib/screens/demo_active_round_screen.dart
// RenkliOkeyScout — Demo Active Round Screen (EINFACH & RICHTIG!)
//
// DER KERN: User wählt die Schrott-Steine in der App.
// App summiert automatisch + multipliziert automatisch.
//
// Flow pro Spieler:
//   1. "Schrott-Steine wählen" → Bottom-Sheet mit 4×13 Grid
//   2. User tippt jeden Stein den der Spieler noch hat
//   3. App zeigt: "5 Steine, Summe = 47"
//   4. Multiplikator-Toggles (Gewinner, Joker, Çifte)
//   5. Foto (optional)
//   6. Gösterge (optional)
//   7. Live-Vorschau: "47 × 5 × 2 = 470 Strafpunkte"

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

  @override
  void initState() {
    super.initState();
    _demo.simulateAIPenalties();
  }

  Future<void> _takePhoto(String playerId) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (photo != null) {
        setState(() {
          final p = _demo.players.firstWhere((pl) => pl.id == playerId);
          p.photoSubmitted = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Foto gespeichert (kein Penalty)'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF3FB950),
            ),
          );
        }
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

  Future<void> _pickSchrottTiles(DemoPlayer player) async {
    final result = await showModalBottomSheet<List<Tile>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _TilePickerSheet(
        initialTiles: List.from(player.schrottTiles),
        jokerTile: _demo.currentJokerTile,
      ),
    );
    if (result != null) {
      setState(() => player.schrottTiles = result);
    }
  }

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

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Runde läuft', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── HEADER ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF161B22),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: tischColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tisch: ${_demo.selectedColor.name.toUpperCase()} × ${_demo.tableFactor}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Gösterge: ${gosterge.color.name.toUpperCase()} ${gosterge.number} → Joker = ${_demo.currentJokerTile.color.name.toUpperCase()} ${_demo.currentJokerTile.number}',
                          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
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
                  demo: _demo,
                  tileColor: _tileColor,
                  onPickSchrott: () => _pickSchrottTiles(_demo.players[i]),
                  onCifteToggle: () => setState(() => _demo.players[i].isCifte = !_demo.players[i].isCifte),
                  onJokerToggle: () => setState(() => _demo.players[i].isJokerFinish = !_demo.players[i].isJokerFinish),
                  onWinnerToggle: () => setState(() => _demo.players[i].isWinner = !_demo.players[i].isWinner),
                  onRemoveGosterge: () => setState(() => _demo.removeGostergeFrom(_demo.players[i].id)),
                  onApplyGosterge: () => setState(() => _demo.applyGostermeTo(_demo.players[i].id)),
                  onTakePhoto: () => _takePhoto(_demo.players[i].id),
                  onRemoveSchrottTile: (tile) => setState(() => _demo.players[i].schrottTiles.remove(tile)),
                  hasGosterge: _demo.hasGostergeHolder == _demo.players[i].id,
                  gostergeHolder: _demo.hasGostergeHolder,
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
                        value: _demo.hasGostergeHolder != null
                            ? _demo.players.firstWhere((p) => p.id == _demo.hasGostergeHolder).name
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
}

// ─── SPIELER-KARTE ────────────────────────────────────────────────────────────

class _PlayerCard extends StatelessWidget {
  final DemoPlayer player;
  final DemoState demo;
  final Color Function(TileColor) tileColor;
  final VoidCallback onPickSchrott;
  final VoidCallback onCifteToggle;
  final VoidCallback onJokerToggle;
  final VoidCallback onWinnerToggle;
  final VoidCallback onRemoveGosterge;
  final VoidCallback onApplyGosterge;
  final VoidCallback onTakePhoto;
  final void Function(Tile) onRemoveSchrottTile;
  final bool hasGosterge;
  final String? gostergeHolder;

  const _PlayerCard({
    required this.player,
    required this.demo,
    required this.tileColor,
    required this.onPickSchrott,
    required this.onCifteToggle,
    required this.onJokerToggle,
    required this.onWinnerToggle,
    required this.onRemoveGosterge,
    required this.onApplyGosterge,
    required this.onTakePhoto,
    required this.onRemoveSchrottTile,
    required this.hasGosterge,
    required this.gostergeHolder,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = player.isWinner;
    final tiles = player.schrottTiles;
    final schrottSum = player.schrottSum;
    final cifte = player.isCifte;
    final joker = player.isJokerFinish;

    final previewPenalty = demo.calculatePenalty(player) * (joker ? 2 : 1) * (cifte ? 2 : 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner
              ? const Color(0xFF3FB950)
              : hasGosterge
                  ? const Color(0xFFF0C000)
                  : const Color(0xFF30363D),
          width: isWinner || hasGosterge ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── ZEILE 1: Name + Status ───
          Row(
            children: [
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.emoji_events, color: Color(0xFF3FB950), size: 20),
                ),
              Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasGosterge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0C000).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Color(0xFFF0C000), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Gösterge',
                        style: TextStyle(color: Color(0xFFF0C000), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── ZEILE 2: Schrott-Steine wählen ───
          // DER KERN: User wählt die Schrott-Steine in der App!
          OutlinedButton.icon(
            onPressed: onPickSchrott,
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(
              tiles.isEmpty
                  ? 'Schrott-Steine wählen'
                  : '${tiles.length} Schrott-Steine (Summe: $schrottSum)',
              style: const TextStyle(fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: tiles.isEmpty
                  ? const Color(0xFF8B949E)
                  : const Color(0xFFF0C000),
              side: BorderSide(
                color: tiles.isEmpty
                    ? const Color(0xFF30363D)
                    : const Color(0xFFF0C000),
              ),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // ─── GEWÄHLTE STEINE (mit X zum Entfernen) ───
          if (tiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tiles.map((tile) {
                return _MiniTile(
                  tile: tile,
                  color: tileColor(tile.color),
                  onRemove: () => onRemoveSchrottTile(tile),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 12),

          // ─── ZEILE 3: Multiplikator-Toggles ───
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ToggleChip(
                label: 'Gewinner',
                icon: Icons.emoji_events,
                selected: isWinner,
                color: const Color(0xFF3FB950),
                onTap: onWinnerToggle,
              ),
              _ToggleChip(
                label: 'Joker ×2',
                icon: Icons.auto_awesome,
                selected: joker,
                color: const Color(0xFF8957E5),
                onTap: onJokerToggle,
              ),
              _ToggleChip(
                label: 'Çifte ×2',
                icon: Icons.copy_all,
                selected: cifte,
                color: const Color(0xFF1F6FEB),
                onTap: onCifteToggle,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ─── ZEILE 4: FOTO ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: player.photoSubmitted
                  ? const Color(0xFF3FB950).withValues(alpha: 0.15)
                  : const Color(0xFFDA3633).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: player.photoSubmitted
                    ? const Color(0xFF3FB950)
                    : const Color(0xFFDA3633),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  player.photoSubmitted ? Icons.check_circle : Icons.warning_amber,
                  color: player.photoSubmitted ? const Color(0xFF3FB950) : const Color(0xFFDA3633),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    player.photoSubmitted
                        ? 'Foto gemacht (kein Penalty)'
                        : 'Kein Foto = +100 Strafpunkte',
                    style: TextStyle(
                      color: player.photoSubmitted ? const Color(0xFF3FB950) : const Color(0xFFDA3633),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!player.photoSubmitted)
                  TextButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.photo_camera, size: 16),
                    label: const Text('Foto'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1F6FEB),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ─── ZEILE 5: Gösterge ───
          if (gostergeHolder == null)
            OutlinedButton.icon(
              onPressed: onApplyGosterge,
              icon: const Icon(Icons.local_fire_department, size: 16),
              label: Text('Hat Gösterge (${demo.currentGostergeTile.color.name.toUpperCase()} ${demo.currentGostergeTile.number})'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF0C000),
                side: const BorderSide(color: Color(0xFFF0C000)),
                minimumSize: const Size(double.infinity, 36),
              ),
            )
          else if (hasGosterge)
            OutlinedButton.icon(
              onPressed: onRemoveGosterge,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Gösterge zurückziehen'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDA3633),
                side: const BorderSide(color: Color(0xFFDA3633)),
                minimumSize: const Size(double.infinity, 36),
              ),
            ),

          const SizedBox(height: 12),

          // ─── ZEILE 6: Vorschau ───
          const Divider(color: Color(0xFF30363D), height: 24),
          Row(
            children: [
              const Text(
                'Strafpunkte:',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const Spacer(),
              Text(
                tiles.isEmpty
                    ? '—'
                    : '$schrottSum × ${demo.tableFactor}${joker ? " × 2" : ""}${cifte ? " × 2" : ""} = ',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              Text(
                tiles.isEmpty ? '—' : '$previewPenalty',
                style: TextStyle(
                  color: tiles.isEmpty ? const Color(0xFF8B949E) : const Color(0xFFDA3633),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── TILE PICKER BOTTOM-SHEET ──────────────────────────────────────────────────

class _TilePickerSheet extends StatefulWidget {
  final List<Tile> initialTiles;
  final Tile jokerTile;

  const _TilePickerSheet({
    required this.initialTiles,
    required this.jokerTile,
  });

  @override
  State<_TilePickerSheet> createState() => _TilePickerSheetState();
}

class _TilePickerSheetState extends State<_TilePickerSheet> {
  late List<Tile> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialTiles);
  }

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  void _toggle(Tile tile) {
    setState(() {
      // Suche gleichen Tile (Farbe + Nummer)
      final existingIndex = _selected.indexWhere(
        (t) => t.color == tile.color && t.number == tile.number,
      );
      if (existingIndex >= 0) {
        _selected.removeAt(existingIndex);
      } else {
        _selected.add(tile);
      }
    });
  }

  bool _isSelected(Tile tile) {
    return _selected.any((t) => t.color == tile.color && t.number == tile.number);
  }

  @override
  Widget build(BuildContext context) {
    final sum = _selected.fold(0, (s, t) => s + t.number);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── HEADER ───
            Row(
              children: [
                const Text(
                  'Schrott-Steine wählen',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_selected.length} Steine · Summe = $sum',
                  style: const TextStyle(color: Color(0xFFF0C000), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Tippe auf jeden Stein, den der Spieler noch auf der Hand hat.',
              style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // ─── GEWÄHLTE STEINE (Vorschau) ───
            if (_selected.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selected.map((t) => _MiniTile(
                    tile: t,
                    color: _tileColor(t.color),
                    onRemove: () => _toggle(t),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ─── GRID: 4 Farben × 13 Zahlen ───
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: TileColor.values.map((color) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          // Farb-Label
                          Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _tileColor(color),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              color.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 13 Zahlen-Buttons
                          Expanded(
                            child: Wrap(
                              spacing: 3,
                              runSpacing: 3,
                              children: List.generate(13, (i) => i + 1).map((n) {
                                final tile = Tile(color, n);
                                final selected = _isSelected(tile);
                                final isJoker = tile.color == widget.jokerTile.color &&
                                                tile.number == widget.jokerTile.number;
                                return InkWell(
                                  onTap: () => _toggle(tile),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? _tileColor(color)
                                          : _tileColor(color).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isJoker
                                            ? const Color(0xFF8957E5)
                                            : _tileColor(color),
                                        width: isJoker ? 2 : 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$n',
                                      style: TextStyle(
                                        color: selected ? Colors.white : _tileColor(color),
                                        fontSize: 12,
                                        fontWeight: isJoker ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ─── BUTTONS: OK / ABBRECHEN ───
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Abbrechen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF238636),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      _selected.isEmpty
                          ? 'Leere Hand (0)'
                          : 'OK ($_selected.length, Summe $sum)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
}

// ─── HILFS-WIDGETS ────────────────────────────────────────────────────────────

class _MiniTile extends StatelessWidget {
  final Tile tile;
  final Color color;
  final VoidCallback onRemove;

  const _MiniTile({required this.tile, required this.color, required this.onRemove});

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : const Color(0xFF30363D),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? color : const Color(0xFF8B949E), size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : const Color(0xFF8B949E),
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
