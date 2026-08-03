// lib/screens/demo_active_round_screen.dart
// RenkliOkeyScout — Demo Active Round Screen (EINFACH!)
//
// Einfaches UI wie ein Zettel:
//   - 4 Spieler in einer klaren Liste
//   - Pro Spieler: Steps mit +/− für Strafpunkte
//   - Live-Anzeige der Multiplikatoren
//   - Große "Runde auswerten" Button
//
// KEIN Foto, KEIN ONNX, KEINE komplizierte Dialoge.

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
          // Simulate photoSubmitted=true (in echter App: upload to Supabase)
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

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }

  String _winTypeLabel(WinType w) {
    switch (w) {
      case WinType.normal:    return 'Normal';
      case WinType.okey:      return 'Okey';
      case WinType.cifte:     return 'Çifte';
      case WinType.okeyCifte: return 'Okey+Çifte';
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
            // ─── HEADER: Tischfarbe + Gösterge Info ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF161B22),
              child: Row(
                children: [
                  // Tischfarbe Badge
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
                          'Tischfarbe: ${_demo.selectedColor.name.toUpperCase()} × ${_demo.tableFactor}',
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
                  onBasisChanged: (n) => setState(() => _demo.players[i].penaltyBasis = n),
                  onCifteToggle: () => setState(() => _demo.players[i].isCifte = !_demo.players[i].isCifte),
                  onJokerToggle: () => setState(() => _demo.players[i].isJokerFinish = !_demo.players[i].isJokerFinish),
                  onWinnerToggle: () => setState(() => _demo.players[i].isWinner = !_demo.players[i].isWinner),
                  onRemoveGosterge: () => setState(() => _demo.removeGostergeFrom(_demo.players[i].id)),
                  onApplyGosterge: () => setState(() => _demo.applyGostermeTo(_demo.players[i].id)),
                  onTakePhoto: () => _takePhoto(_demo.players[i].id),
                  hasGosterge: _demo.hasGostergeHolder == _demo.players[i].id,
                  gostergeHolder: _demo.hasGostergeHolder,
                  winTypeLabel: _winTypeLabel(_demo.players[i].winType),
                  tableFactor: _demo.tableFactor,
                  gostergeTile: _demo.currentGostergeTile,
                ),
              ),
            ),

            // ─── BOTTOM BAR: Ergebnis + Button ───
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF161B22),
                border: Border(top: BorderSide(color: Color(0xFF30363D))),
              ),
              child: Column(
                children: [
                  // Zusammenfassung
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SummaryChip(
                        label: 'Höchste',
                        value: '${_demo.players.map((p) => p.penaltyBasis).reduce((a, b) => a > b ? a : b)}',
                        color: const Color(0xFFDA3633),
                      ),
                      _SummaryChip(
                        label: 'Schnitt',
                        value: (_demo.players.map((p) => p.penaltyBasis).fold(0, (a, b) => a + b) / _demo.players.length).toStringAsFixed(1),
                        color: const Color(0xFF8B949E),
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
  final ValueChanged<int> onBasisChanged;
  final VoidCallback onCifteToggle;
  final VoidCallback onJokerToggle;
  final VoidCallback onWinnerToggle;
  final VoidCallback onRemoveGosterge;
  final VoidCallback onApplyGosterge;
  final VoidCallback onTakePhoto;
  final bool hasGosterge;
  final String? gostergeHolder;
  final String winTypeLabel;
  final int tableFactor;
  final Tile gostergeTile;

  const _PlayerCard({
    required this.player,
    required this.onBasisChanged,
    required this.onCifteToggle,
    required this.onJokerToggle,
    required this.onWinnerToggle,
    required this.onRemoveGosterge,
    required this.onApplyGosterge,
    required this.onTakePhoto,
    required this.hasGosterge,
    required this.gostergeHolder,
    required this.winTypeLabel,
    required this.tableFactor,
    required this.gostergeTile,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = player.isWinner;
    final basis = player.penaltyBasis;
    final cifte = player.isCifte;
    final joker = player.isJokerFinish;

    // Vorschau Strafpunkte
    final previewPenalty = basis * tableFactor * (joker ? 2 : 1) * (cifte ? 2 : 1);

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
              // Gewinner-Stern
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, color: Color(0xFFF0C000), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Gösterge',
                        style: const TextStyle(color: Color(0xFFF0C000), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ─── ZEILE 2: Strafpunkte-Steps ───
          Row(
            children: [
              const Text(
                'Schrott:',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
              ),
              const Spacer(),
              _StepButton(
                icon: Icons.remove,
                onPressed: basis > 0 ? () => onBasisChanged(basis - 1) : null,
              ),
              Container(
                width: 50,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$basis',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onPressed: basis < 14 ? () => onBasisChanged(basis + 1) : null,
              ),
            ],
          ),

          const SizedBox(height: 8),

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

          // ─── ZEILE 3.5: FOTO-Button (Kern des Spiels!) ───
          // Regel: Kein Foto = +100 Strafpunkte
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

          const SizedBox(height: 12),

          // ─── ZEILE 4: Gösterge (nur wenn definiert) ───
          if (gostergeHolder == null)
            OutlinedButton.icon(
              onPressed: onApplyGosterge,
              icon: const Icon(Icons.local_fire_department, size: 16),
              label: Text('Hat Gösterge (${gostergeTile.color.name.toUpperCase()} ${gostergeTile.number})'),
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

          // ─── ZEILE 5: Vorschau ───
          const Divider(color: Color(0xFF30363D), height: 24),
          Row(
            children: [
              const Text(
                'Strafpunkte:',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const Spacer(),
              Text(
                '$basis × $tableFactor${joker ? " × 2" : ""}${cifte ? " × 2" : ""} = ',
                style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
              ),
              Text(
                '$previewPenalty',
                style: const TextStyle(
                  color: Color(0xFFDA3633),
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

// ─── HILFS-WIDGETS ────────────────────────────────────────────────────────────

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _StepButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF21262D),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFF30363D)),
          ),
        ),
        child: Icon(icon, size: 20),
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
