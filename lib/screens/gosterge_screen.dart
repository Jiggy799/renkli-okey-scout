// lib/screens/gosterge_screen.dart
// RenkliOkeyScout — Gösterge Selection: table host picks the face-up tile

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../utils/score_calculator.dart';

class GostergeScreen extends StatefulWidget {
  final String tableId;
  final int roundNumber;

  const GostergeScreen({
    super.key,
    required this.tableId,
    required this.roundNumber,
  });

  @override
  State<GostergeScreen> createState() => _GostergeScreenState();
}

class _GostergeScreenState extends State<GostergeScreen> {
  TileColor _selectedColor = TileColor.yellow;
  int _selectedNumber = 1;
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  Future<void> _confirm() async {
    setState(() => _isLoading = true);

    final gostergeJson = '{"color":"${_selectedColor.name}","number":$_selectedNumber}';

    await _supabase.from('tables').update({
      'gosterge_tile': gostergeJson,
    }).eq('id', widget.tableId);

    // Create round record
    await _supabase.from('rounds').insert({
      'table_id': widget.tableId,
      'round_number': widget.roundNumber,
      'gosterge_tile': gostergeJson,
    });

    if (mounted) {
      context.go('/round/${widget.tableId}');
    }
  }

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow:
        return const Color(0xFFF0C000);
      case TileColor.blue:
        return const Color(0xFF1F6FEB);
      case TileColor.red:
        return const Color(0xFFDA3633);
      case TileColor.black:
        return const Color(0xFF6E7681);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${widget.roundNumber} — Gösterge',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/lobby'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Gösterge wählen',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Welche Farbe zeigt der offene Stein?',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Color selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: TileColor.values.map((color) {
                  final isSelected = _selectedColor == color;
                  final factor = tableColorFactor(color);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _tileColor(color),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _tileColor(color).withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            color.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '×$factor',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Number selector
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Offene Nummer',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: List.generate(13, (i) {
                        final n = i + 1;
                        final isSelected = _selectedNumber == n;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedNumber = n),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _tileColor(_selectedColor)
                                  : const Color(0xFF21262D),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF30363D),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _tileColor(_selectedColor).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _tileColor(_selectedColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TileWidget(
                      color: _tileColor(_selectedColor),
                      number: _selectedNumber,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedColor.name.toUpperCase(),
                          style: TextStyle(
                            color: _tileColor(_selectedColor),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Faktor ×${tableColorFactor(_selectedColor)}',
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF238636),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Gösterge bestätigen',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final Color color;
  final int number;

  const _TileWidget({required this.color, required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}
