// lib/screens/demo_round_result_screen.dart
// Shows after each round in demo mode

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';

class DemoRoundResultScreen extends StatelessWidget {
  const DemoRoundResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = DemoState();
    final lastRound = demo.rounds.isNotEmpty ? demo.rounds.last : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${demo.currentRound - 1} · Ergebnis',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Round summary
              if (lastRound != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Runden-Info',
                        style: TextStyle(
                          color: Color(0xFFF0C000),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _infoRow('Tischfarbe',
                          '${lastRound.tableColor.name} (×${tableColorFactor(lastRound.tableColor)})'),
                      if (lastRound.gostergeShownBy != null)
                        _infoRow('Gösterme',
                            '${demo.players.firstWhere((p) => p.id == lastRound.gostergeShownBy, orElse: () => demo.players.first).name} zeigte'),
                      _infoRow('Gosterge', '${lastRound.gostergeTile.color.name[0].toUpperCase()}${lastRound.gostergeTile.number}'),
                      _infoRow('Joker', '${lastRound.jokerTile.color.name[0].toUpperCase()}${lastRound.jokerTile.number}'),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Players
              Expanded(
                child: ListView.builder(
                  itemCount: demo.players.length,
                  itemBuilder: (ctx, i) {
                    final p = demo.players[i];
                    final roundPenalty = p.cumulativePenalty;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(
                                color: Color(0xFFF0C000), fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Text(
                            '$roundPenalty P',
                            style: TextStyle(
                              color: p.isHuman
                                  ? const Color(0xFF58A6FF)
                                  : const Color(0xFF8B949E),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Next round / finish
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (demo.isGameOver) {
                      context.go('/demo-gameover');
                    } else {
                      context.go('/demo-round');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    demo.isGameOver
                        ? 'Spiel beenden'
                        : 'Nächste Runde (${demo.currentRound}/11)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
