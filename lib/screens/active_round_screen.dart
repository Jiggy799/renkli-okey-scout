// lib/screens/active_round_screen.dart
// RenkliOkeyScout — Active Round Scoreboard Dashboard

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../utils/score_calculator.dart';

class ActiveRoundScreen extends StatefulWidget {
  final String tableId;

  const ActiveRoundScreen({super.key, required this.tableId});

  @override
  State<ActiveRoundScreen> createState() => _ActiveRoundScreenState();
}

class _ActiveRoundScreenState extends State<ActiveRoundScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _players = [];
  TileColor _selectedColor = TileColor.black;
  WinType _winType = WinType.normal;
  String? _localUserId;
  final Map<String, bool> _gostermeApplied = {};
  final Map<String, bool> _cifteStatus = {};

  @override
  void initState() {
    super.initState();
    _localUserId = _supabase.auth.currentUser?.id;
    _loadTable();
    _subscribeToChanges();
  }

  Future<void> _loadTable() async {
    final table = await _supabase
        .from('tables')
        .select('*, table_players(*, profiles(id, username, avatar_url))')
        .eq('id', widget.tableId)
        .single();

    final gostergeRaw = table['gosterge_tile'];
    TileColor parsedColor = TileColor.black;
    if (gostergeRaw != null) {
      try {
        final gMap = jsonDecode(gostergeRaw) as Map<String, dynamic>;
        parsedColor = TileColor.values.firstWhere(
          (c) => c.name == gMap['color'],
          orElse: () => TileColor.black,
        );
      } catch (_) {}
    }

    final players = List<Map<String, dynamic>>.from(
        (table['table_players'] as List?) ?? []);

    if (mounted) {
      setState(() {
        _table = Map<String, dynamic>.from(table);
        _selectedColor = parsedColor;
        _players = players;
        for (final p in players) {
          _cifteStatus[p['player_id'] ?? ''] = p['is_cifte'] ?? false;
        }
      });
    }
  }

  RealtimeChannel? _roundChannel;

  void _subscribeToChanges() {
    _roundChannel?.unsubscribe();
    _roundChannel = _supabase.channel('round_${widget.tableId}');

    _roundChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'table_players',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final rowTableId = newRecord['table_id']?.toString() ?? '';
            if (rowTableId != widget.tableId) return;
            _loadTable();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tables',
          callback: (payload) {
            final newRecord = payload.newRecord;
            final rowTableId = newRecord['id']?.toString() ?? '';
            if (rowTableId != widget.tableId) return;
            _loadTable();
          },
        )
        .subscribe();
  }

  Future<void> _setGosterge(TileColor color, int number) async {
    final gostergeJson = '{"color":"${color.name}","number":$number}';
    await _supabase.from('tables').update({
      'gosterge_tile': gostergeJson,
    }).eq('id', widget.tableId);
    setState(() => _selectedColor = color);
  }

  Future<void> _toggleCifte(String playerId) async {
    final current = _cifteStatus[playerId] ?? false;
    await _supabase.from('table_players').update({
      'is_cifte': !current,
    }).eq('player_id', playerId).eq('table_id', widget.tableId);
    setState(() => _cifteStatus[playerId] = !current);
    _loadTable();
  }

  /// Gösterme Variante B: Der Spieler MIT dem Gösterge-Stein bekommt
  /// NEGATIVE Punkte (geht ins Minus). Andere 3 bekommen nichts.
  /// DB: Round merkt sich wer gezeigt hat + Farbe; profiles.gosterge_show_count++
  Future<void> _applyGosterme(String playerId) async {
    final penalty = berechneGostermeStrafeHalter(_selectedColor); // negativ, z.B. -5

    // DB: rounds merken WER gezeigt hat + Farbe (System B)
    final currentRound = (_table?['current_round'] as int?) ?? 1;
    await _supabase.from('rounds').update({
      'gosterge_shown_by': playerId,
      'gosterge_show_color': _selectedColor.name,
    }).eq('table_id', widget.tableId).eq('round_number', currentRound);

    // DB: profiles.gosterge_show_count++ (System B)
    await _supabase.rpc('increment_gosterge_count', params: {'player_uuid': playerId});

    // DB: cumulative_penalty += penalty (negativ = Minus vom Penalty abziehen)
    final gostergePlayer = _players.firstWhere(
      (p) => p['player_id'] == playerId,
      orElse: () => {},
    );
    if (gostergePlayer.isNotEmpty) {
      final current = (gostergePlayer['cumulative_penalty'] as int?) ?? 0;
      await _supabase.from('table_players').update({
        'cumulative_penalty': current + penalty, // +(-5) = -5
      }).eq('player_id', playerId).eq('table_id', widget.tableId);
    }

    setState(() => _gostermeApplied[playerId] = true);
    _loadTable();
  }

  Future<void> _submitPenalty(String playerId, int basisPunkte) async {
    final isCifte = _cifteStatus[playerId] ?? false;
    // Joker/Cifte-Multiplikator kommt vom Gewinner (hier aus _winType)
    final winnerWinType = isCifte
        ? (_winType == WinType.okey ? WinType.okeyCifte : WinType.cifte)
        : (_winType == WinType.cifte ? WinType.cifte : _winType);
    final penalty = berechneStrafpunkte(
      basisPunkte: basisPunkte,
      tableColor: _selectedColor,
      winType: winnerWinType,
    );
    final current = (_players.firstWhere(
      (p) => p['player_id'] == playerId,
      orElse: () => {'cumulative_penalty': 0},
    )['cumulative_penalty'] as int?) ?? 0;

    await _supabase.from('table_players').update({
      'cumulative_penalty': current + penalty,
    }).eq('player_id', playerId).eq('table_id', widget.tableId);
    _loadTable();
  }

  void _showEndRoundDialog(BuildContext context) {
    final currentRound = (_table?['current_round'] as int?) ?? 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Runde beenden?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Alle Spieler tragen ihre Minuspunkte ein. Weiter zur Ergebniseingabe?',
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
              context.push(
                  '/round-result/${widget.tableId}/${currentRound == 0 ? 1 : currentRound}');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
  }

  Color get _tableColorColor {
    switch (_selectedColor) {
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

  int get _tableFactor => tableColorFactor(_selectedColor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Tisch ${widget.tableId}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag, color: Color(0xFFF0C000)),
            onPressed: () => _showEndRoundDialog(context),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _colorChip(TileColor.yellow, '×2'),
          const SizedBox(width: 8),
          _colorChip(TileColor.blue, '×3'),
          const SizedBox(width: 8),
          _colorChip(TileColor.red, '×4'),
          const SizedBox(width: 8),
          _colorChip(TileColor.black, '×5'),
          const SizedBox(width: 24),
          Column(
            children: [
              const Text(
                'Tischfarbe',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 10),
              ),
              Text(
                _selectedColor.name.toUpperCase(),
                style: TextStyle(
                  color: _tableColorColor,
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

  Widget _colorChip(TileColor color, String mult) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => _setGosterge(color, 13),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _tileColor(color).withValues(alpha: isSelected ? 1.0 : 0.3),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
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

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF0D1117),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Okey atmak',
                  style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _winType == WinType.okey || _winType == WinType.okeyCifte,
                  onChanged: (v) => setState(() {
                    _winType = v
                        ? (_winType == WinType.cifte ? WinType.okeyCifte : WinType.okey)
                        : (_winType == WinType.okeyCifte ? WinType.cifte : WinType.normal);
                  }),
                  activeThumbColor: const Color(0xFF58A6FF),
                  activeTrackColor:
                      const Color(0xFF58A6FF).withValues(alpha: 0.4),
                ),
                if (_winType == WinType.okey || _winType == WinType.okeyCifte)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '×2',
                      style: TextStyle(color: Color(0xFF58A6FF), fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _tableColorColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _tableColorColor, width: 1),
            ),
            child: Text(
              'Faktor ×$_tableFactor${_winType == WinType.okey || _winType == WinType.okeyCifte ? '×2' : ''}${_winType == WinType.cifte || _winType == WinType.okeyCifte ? '×2' : ''}',
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
    if (_players.isEmpty) {
      return const Center(
        child: Text(
          'Keine Spieler',
          style: TextStyle(color: Color(0xFF8B949E)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _players.length,
      itemBuilder: (ctx, i) => _playerCard(_players[i]),
    );
  }

  Widget _playerCard(Map<String, dynamic> player) {
    final playerId = player['player_id'] as String? ?? '';
    final username = player['profiles']?['username'] ?? 'Unbekannt';
    final cumulativePenalty = (player['cumulative_penalty'] as int?) ?? 0;
    final isCifte = _cifteStatus[playerId] ?? false;
    final isGostermeApplied = _gostermeApplied[playerId] ?? false;
    final isLocal = playerId == _localUserId;
    final isCreator = player['is_creator'] as bool? ?? false;
    final seatIndex = (player['seat_index'] as int? ?? 0) + 1;

    final currentFactor = liveFactor(
      tableColor: _selectedColor,
      winType: _winType,
    );

    return Card(
      color: const Color(0xFF161B22),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLocal ? const Color(0xFF58A6FF) : const Color(0xFF30363D),
          width: isLocal ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _tableColorColor.withValues(alpha: 0.2),
                  child: Text(
                    '$seatIndex',
                    style: TextStyle(
                      color: _tableColorColor,
                      fontWeight: FontWeight.bold,
                    ),
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
                            username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (isCreator) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star,
                                color: Color(0xFFF0C000), size: 14),
                          ],
                          if (isLocal) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF58A6FF)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'DU',
                                style: TextStyle(
                                    color: Color(0xFF58A6FF), fontSize: 9),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Strafpunkte: $cumulativePenalty',
                        style: const TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _tableColorColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _tableColorColor, width: 1),
                  ),
                  child: Text(
                    '×$currentFactor',
                    style: TextStyle(
                      color: _tableColorColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Çifte',
                    icon: Icons.compare_arrows,
                    isActive: isCifte,
                    activeColor: const Color(0xFFF0C000),
                    onTap: () => _toggleCifte(playerId),
                    subtitle: isCifte ? '×2 eigene' : 'aus',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    label: 'Gösterme',
                    icon: Icons.visibility,
                    isActive: isGostermeApplied,
                    activeColor: const Color(0xFF238636),
                    onTap: isGostermeApplied
                        ? null
                        : () => _applyGosterme(playerId),
                    subtitle: isGostermeApplied
                        ? '✓ Gösterme: ${berechneGostermeStrafeHalter(_selectedColor)}'
                        : 'Zeigen (${berechneGostermeStrafeHalter(_selectedColor)})',
                  ),
                ),
                const SizedBox(width: 8),
                _QuickPenaltyButtons(
                  onAdd1: () => _submitPenalty(playerId, 1),
                  onAdd5: () => _submitPenalty(playerId, 5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _roundChannel?.unsubscribe();
    super.dispose();
  }
}

// ─── Small helper widgets ───────────────────────────────────────────────────

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
            Icon(
              icon,
              size: 18,
              color: isActive ? activeColor : const Color(0xFF8B949E),
            ),
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
                  color:
                      (isActive ? activeColor : const Color(0xFF8B949E))
                          .withValues(alpha: 0.7),
                  fontSize: 9,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickPenaltyButtons extends StatelessWidget {
  final VoidCallback onAdd1;
  final VoidCallback onAdd5;

  const _QuickPenaltyButtons({
    required this.onAdd1,
    required this.onAdd5,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _miniBtn('+1', onAdd1, const Color(0xFFDA3633)),
        const SizedBox(height: 4),
        _miniBtn('+5', onAdd5, const Color(0xFFDA3633)),
      ],
    );
  }

  Widget _miniBtn(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
