// lib/screens/game_over_screen.dart
// RenkliOkeyScout — Final scores when table is closed
// System B: Gösterge-Bonus wird von Gesamt-Penalty abgezogen

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../utils/score_calculator.dart';

class GameOverScreen extends StatefulWidget {
  final String tableId;

  const GameOverScreen({super.key, required this.tableId});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _players = [];
  /// playerId → gesamte Gösterge-Bonus-Minuspunkte (System B)
  Map<String, int> _gostergeBonus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final table = await Supabase.instance.client
        .from('tables')
        .select('*, table_players(*, profiles(id, username))')
        .eq('id', widget.tableId)
        .single();

    // Load all rounds to find gösterge-show events (System B)
    final rounds = await Supabase.instance.client
        .from('rounds')
        .select('gosterge_shown_by, gösterge_show_color')
        .eq('table_id', widget.tableId)
        .not('gosterge_shown_by', 'is', null);

    // Sum up gösterge bonus per player: each show = color-based penalty
    final Map<String, int> bonusSum = {};
    for (final r in rounds) {
      final pid = r['gosterge_shown_by'] as String?;
      final colorStr = r['gösterge_show_color'] as String? ?? 'yellow';
      if (pid != null) {
        final color = TileColor.values.firstWhere(
          (c) => c.name == colorStr,
          orElse: () => TileColor.blue,
        );
        bonusSum[pid] = (bonusSum[pid] ?? 0) + gostergeShowBonus(color);
      }
    }

    final players = List<Map<String, dynamic>>.from(
        (table['table_players'] as List?) ?? []);

    // Sort by FINAL penalty (cumulative_penalty - gösterge_bonus)
    players.sort((a, b) {
      final pa = _finalPenalty(a, bonusSum);
      final pb = _finalPenalty(b, bonusSum);
      return pa.compareTo(pb);
    });

    if (mounted) {
      setState(() {
        _table = Map<String, dynamic>.from(table);
        _players = players;
        _gostergeBonus = bonusSum;
        _isLoading = false;
      });
    }
  }

  /// System B: Kumulativer Gösterge-Bonus für einen Spieler (Minuspunkte)
  int _gostergeBonusFor(String playerId) {
    return _gostergeBonus[playerId] ?? 0;
  }

  /// Finaler Penalty = cumulative_penalty - gösterge_bonus (kann negativ werden!)
  int _finalPenalty(Map<String, dynamic> player, Map<String, int> bonusSum) {
    final cumulative = (player['cumulative_penalty'] as int?) ?? 0;
    final pid = player['player_id'] ?? '';
    return cumulative - (bonusSum[pid] ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Spielende', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF58A6FF)))
            : Column(
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.emoji_events, color: Color(0xFFF0C000), size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    'Ergebnisse',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  if (_table != null)
                    Text(
                      'Tisch ${_table!['id']} · ${_table!['current_round']} Runden',
                      style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                    ),
                  const SizedBox(height: 32),

                  // Podium
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _players.length,
                      itemBuilder: (context, i) {
                        final p = _players[i];
                        final name = p['profiles']?['username'] ?? 'Unbekannt';
                        final pid = p['player_id'] ?? '';
                        final cumulative = (p['cumulative_penalty'] as int?) ?? 0;
                        final bonus = _gostergeBonusFor(pid);
                        final finalPenalty = cumulative - bonus;
                        final isWinner = i == 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isWinner
                                ? const Color(0xFFF0C000).withValues(alpha: 0.1)
                                : const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isWinner
                                  ? const Color(0xFFF0C000)
                                  : const Color(0xFF30363D),
                              width: isWinner ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isWinner
                                          ? const Color(0xFFF0C000)
                                          : const Color(0xFF30363D),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '#${i + 1}',
                                        style: TextStyle(
                                          color: isWinner ? Colors.black : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: isWinner ? const Color(0xFFF0C000) : Colors.white,
                                        fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$finalPenalty',
                                        style: TextStyle(
                                          color: isWinner ? const Color(0xFFF0C000) : const Color(0xFF8B949E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 24,
                                        ),
                                      ),
                                      if (bonus > 0)
                                        Text(
                                          '−$bonus Bonus',
                                          style: const TextStyle(
                                            color: Color(0xFF238636),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 4),
                                  const Text('P', style: TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
                                ],
                              ),
                              if (bonus > 0) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF238636).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.visibility, color: Color(0xFF238636), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Gösterme: −$bonus Punkte (System B)',
                                        style: const TextStyle(
                                          color: Color(0xFF238636),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/lobby'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF238636),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Neuer Tisch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
