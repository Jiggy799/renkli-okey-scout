// lib/screens/demo_game_over_screen.dart
// Final results after 11 rounds in demo mode

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../demo/demo_state.dart';

class DemoGameOverScreen extends StatelessWidget {
  const DemoGameOverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final demo = DemoState();
    final sorted = demo.sortedByPenalty;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Spielende', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.emoji_events, color: Color(0xFFF0C000), size: 64),
            const SizedBox(height: 12),
            const Text(
              'Ergebnisse',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${demo.rounds.length} Runden gespielt',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
            ),
            const SizedBox(height: 32),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: sorted.length,
                itemBuilder: (ctx, i) {
                  final p = sorted[i];
                  final finalP = demo.finalPenaltyFor(p.id);
                  final bonus = demo.gostergeBonusFor(p.id);
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
                        color: isWinner ? const Color(0xFFF0C000) : const Color(0xFF30363D),
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
                                color: isWinner ? const Color(0xFFF0C000) : const Color(0xFF30363D),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        p.name,
                                        style: TextStyle(
                                          color: isWinner ? const Color(0xFFF0C000) : Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      if (p.isHuman) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'DU',
                                            style: TextStyle(color: Color(0xFF58A6FF), fontSize: 10),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (bonus > 0)
                                    Text(
                                      'Gösterme: −$bonus (System B)',
                                      style: const TextStyle(color: Color(0xFF238636), fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$finalP',
                                  style: TextStyle(
                                    color: isWinner ? const Color(0xFFF0C000) : const Color(0xFF8B949E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                                const Text(
                                  'Punkte',
                                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (sorted.isNotEmpty && sorted.first.isHuman)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0C000).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF0C000)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.celebration, color: Color(0xFFF0C000)),
                          SizedBox(width: 8),
                          Text(
                            'Du hast gewonnen!',
                            style: TextStyle(
                              color: Color(0xFFF0C000),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        demo.reset();
                        context.go('/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF238636),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Neue Demo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
