// lib/screens/round_result_screen.dart
// RenkliOkeyScout — Round Result: alle 4 müssen fotografieren, sonst +100

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/score_calculator.dart';
import '../services/vision_service.dart';

class RoundResultScreen extends StatefulWidget {
  final String tableId;
  final int roundNumber;

  const RoundResultScreen({
    super.key,
    required this.tableId,
    required this.roundNumber,
  });

  @override
  State<RoundResultScreen> createState() => _RoundResultScreenState();
}

class _RoundResultScreenState extends State<RoundResultScreen> {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _table;
  List<Map<String, dynamic>> _players = [];
  String? _winnerId;
  String? _localUserId;
  TileColor _tableColor = TileColor.black;
  WinType _winType = WinType.normal;

  /// Spieler die ihr Foto bestätigt haben (Kamera-Button gedrückt).
  /// MÜSSEN alle 4 sein um Strafe zu vermeiden.
  final Set<String> _photoConfirmed = {};

  // Manual penalty input per player
  final Map<String, int> _penaltyInputs = {};
  final Map<String, TextEditingController> _controllers = {};

  bool _isSubmitting = false;
  bool _submitted = false;

  // ── Vision / Camera ────────────────────────────────────────────────────
  final _visionService = VisionService(
    httpProxyUrl: 'http://192.168.178.187:5000/analyse',
  );
  final _imagePicker = ImagePicker();

  // Basis-Punkte die via Kamera erkannt wurden (pro Spieler-ID)
  final Map<String, int> _aiBasisPunkte = {};

  @override
  void initState() {
    super.initState();
    _localUserId = _supabase.auth.currentUser?.id;
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _visionService.dispose();
    super.dispose();
  }

  // ─── Kamera + Vision AI ────────────────────────────────────────────────

  /// Öffnet die Kamera für den lokalen Spieler, AI-Analyse via Ollama.
  /// Für Remote-Spieler wird nur _photoConfirmed getoggelt.
  Future<void> _openCameraSheet(String playerId) async {
    if (!mounted) return;
    final isLocal = playerId == _localUserId;

    if (!isLocal) {
      // Remote-Spieler: nur als "fotografiert" markieren
      setState(() {
        if (_photoConfirmed.contains(playerId)) {
          _photoConfirmed.remove(playerId);
        } else {
          _photoConfirmed.add(playerId);
        }
      });
      return;
    }

    // Lokaler Spieler: Kamera öffnen + Ollama Vision
    final gostergeRaw = _table?['gosterge_tile'];
    int gostergeNumber = 13;
    if (gostergeRaw != null) {
      try {
        gostergeNumber = (jsonDecode(gostergeRaw)['number'] as int?) ?? 13;
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CameraSheet(
        tableColor: _tableColor,
        gostergeNumber: gostergeNumber,
        visionService: _visionService,
        imagePicker: _imagePicker,
        onAnalyseDone: (basisPunkte) {
          setState(() {
            _aiBasisPunkte[playerId] = basisPunkte;
            _penaltyInputs[playerId] = basisPunkte;
            _photoConfirmed.add(playerId);
            _controllers[playerId]?.text = basisPunkte.toString();
          });
        },
      ),
    );
  }

  Future<void> _loadData() async {
    final table = await _supabase
        .from('tables')
        .select('*, table_players(*, profiles(id, username))')
        .eq('id', widget.tableId)
        .single();

    final gostergeRaw = table['gosterge_tile'];
    if (gostergeRaw != null) {
      final gMap = jsonDecode(gostergeRaw) as Map<String, dynamic>;
      _tableColor = TileColor.values.firstWhere(
        (c) => c.name == gMap['color'],
        orElse: () => TileColor.black,
      );
    }

    // Load current round
    final rounds = await _supabase
        .from('rounds')
        .select('*')
        .eq('table_id', widget.tableId)
        .order('round_number', ascending: false)
        .limit(1);

    if (rounds.isNotEmpty) {
      _winnerId = rounds.first['winner_id'] as String?;
      if (rounds.isNotEmpty) {
        final lastRound = rounds.last as Map<String, dynamic>;
        _winType = WinType.values.firstWhere(
          (w) => w.name == lastRound['win_type'],
          orElse: () => WinType.normal,
        );
      }
    }

    final players = List<Map<String, dynamic>>.from(
        (table['table_players'] as List?) ?? []);

    for (final p in players) {
      final pid = p['player_id'] as String? ?? '';
      _controllers[pid] = TextEditingController();
      _penaltyInputs[pid] = 0;
    }

    if (mounted) {
      setState(() {
        _table = Map<String, dynamic>.from(table);
        _players = players;
      });
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

  int get _missingPhotoCount =>
      _players.where((p) => !_photoConfirmed.contains(p['player_id'])).length;

  int _penaltyFor(String pid) {
    final basis = _penaltyInputs[pid] ?? 0;
    if (basis <= 0) return 0;
    final player = _players.firstWhere((p) => p['player_id'] == pid, orElse: () => {});
    final isCifte = player['is_cifte'] as bool? ?? false;
    // Joker-Multiplikator kommt vom Gewinner.
    return berechneStrafpunkte(
      basisPunkte: schrott,
      tableColor: _tableColor,
      winType: _winType,
    );
  }

  Future<void> _submitResults() async {
    if (_winnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst den Gewinner markieren!')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // ─── Alle 4 Spieler: Foto oder +100 Strafe ───────────────────────────
    for (final player in _players) {
      final pid = player['player_id'] as String? ?? '';
      final isWinner = pid == _winnerId;
      final hasPhoto = _photoConfirmed.contains(pid);

      int extraPenalty = 0;
      if (!hasPhoto) {
        extraPenalty = noPhotoPenalty; // +100
      }

      int totalPenalty = extraPenalty;

      // Verlierer: zusätzlich Minuspunkte
      if (!isWinner) {
        totalPenalty += _penaltyFor(pid);
      }

      if (totalPenalty == 0) continue;

      final current = (player['cumulative_penalty'] as int?) ?? 0;
      await _supabase.from('table_players').update({
        'cumulative_penalty': current + totalPenalty,
      }).eq('player_id', pid).eq('table_id', widget.tableId);
    }

    // ─── Runde als finished markieren ─────────────────────────────────────
    final rounds = await _supabase
        .from('rounds')
        .select('id')
        .eq('table_id', widget.tableId)
        .order('round_number', ascending: false)
        .limit(1);

    if (rounds.isNotEmpty) {
      await _supabase.from('rounds').update({
        'status': 'finished',
        'winner_id': _winnerId,
        'win_type': _winType.name,
        'finished_at': DateTime.now().toIso8601String(),
      }).eq('id', rounds.first['id']);
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
    }
  }

  Future<void> _nextRound() async {
    await _supabase.from('tables').update({
      'current_round': widget.roundNumber + 1,
    }).eq('id', widget.tableId);

    if (mounted) {
      context.go('/gosterge/${widget.tableId}/${widget.roundNumber + 1}');
    }
  }

  Future<void> _endGame() async {
    await _supabase.from('tables').update({
      'status': 'finished',
    }).eq('id', widget.tableId);

    if (mounted) {
      context.go('/gameover/${widget.tableId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_table == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(
          'Runde ${widget.roundNumber} — Ergebnis',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _submitted ? _buildSubmittedView() : _buildInputView(),
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF238636), size: 80),
          const SizedBox(height: 24),
          const Text(
            'Ergebnis eingetragen!',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _nextRound,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Nächste Runde'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _endGame,
            child: const Text('Spiel beenden', style: TextStyle(color: Color(0xFF8B949E))),
          ),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Foto-Pflicht Banner ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _missingPhotoCount == 0
                  ? const Color(0xFF238636).withValues(alpha: 0.15)
                  : const Color(0xFFDA3633).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _missingPhotoCount == 0
                    ? const Color(0xFF238636)
                    : const Color(0xFFDA3633),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _missingPhotoCount == 0 ? Icons.check_circle : Icons.warning,
                  color: _missingPhotoCount == 0
                      ? const Color(0xFF238636)
                      : const Color(0xFFDA3633),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _missingPhotoCount == 0
                        ? 'Alle 4 Spieler haben fotografiert ✓'
                        : 'Noch $_missingPhotoCount Spieler ohne Foto! (+$noPhotoPenalty pro Fehlendem)',
                    style: TextStyle(
                      color: _missingPhotoCount == 0
                          ? const Color(0xFF238636)
                          : const Color(0xFFDA3633),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Tischfarbe Info ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _tileColor(_tableColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_tableColor.name.toUpperCase()} Tisch',
                  style: TextStyle(color: _tileColor(_tableColor), fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('×${tableColorFactor(_tableColor)}',
                    style: const TextStyle(color: Color(0xFF8B949E))),
                const Spacer(),
                Text('Runde ${widget.roundNumber}',
                    style: const TextStyle(color: Color(0xFF8B949E))),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Joker Finish ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: Color(0xFFF0C000), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Okey atmak (Gewinner hat Okey abgeworfen)',
                    style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                  ),
                ),
                Switch(
                  value: _winType == WinType.okey || _winType == WinType.okeyCifte,
                  onChanged: (v) => setState(() {
                    _winType = v
                        ? (_winType == WinType.cifte ? WinType.okeyCifte : WinType.okey)
                        : (_winType == WinType.okeyCifte ? WinType.cifte : WinType.normal);
                  }),
                  activeThumbColor: const Color(0xFFF0C000),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Gewinner wählen ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wer hat gewonnen?',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ..._players.map((p) {
                  final pid = p['player_id'] as String? ?? '';
                  final name = p['profiles']?['username'] ?? 'Unbekannt';
                  final isWinner = _winnerId == pid;
                  final isLocal = pid == _localUserId;

                  return GestureDetector(
                    onTap: () => setState(() => _winnerId = pid),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isWinner
                            ? const Color(0xFF238636).withValues(alpha: 0.2)
                            : const Color(0xFF21262D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isWinner ? const Color(0xFF238636) : const Color(0xFF30363D),
                          width: isWinner ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isWinner ? Icons.emoji_events : Icons.person,
                            color: isWinner ? const Color(0xFFF0C000) : const Color(0xFF8B949E),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isWinner ? Colors.white : const Color(0xFF8B949E),
                                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isLocal)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('DU', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 10)),
                            ),
                          if (isWinner) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check, color: Color(0xFF238636), size: 20),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Alle Spieler: Foto-Bestätigung ─────────────────────────────
          const Text(
            'Foto bestätigt? (Alle 4 müssen fotografieren)',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jeder Spieler muss sein Rack fotografieren — auch der Gewinner!\nOhne Foto: +100 Strafpunkte',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
          ),
          const SizedBox(height: 10),
          ..._players.map((p) {
            final pid = p['player_id'] as String? ?? '';
            final name = p['profiles']?['username'] ?? 'Unbekannt';
            final isWinner = pid == _winnerId;
            final isLocal = pid == _localUserId;
            final hasPhoto = _photoConfirmed.contains(pid);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasPhoto ? const Color(0xFF238636) : const Color(0xFFDA3633),
                  width: hasPhoto ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Kamera-Button → Ollama Vision Sheet
                  GestureDetector(
                    onTap: () => _openCameraSheet(pid),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasPhoto
                            ? const Color(0xFF238636).withValues(alpha: 0.2)
                            : const Color(0xFF30363D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasPhoto ? Icons.check_circle : Icons.camera_alt,
                        color: hasPhoto ? const Color(0xFF238636) : const Color(0xFF8B949E),
                        size: 24,
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
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            if (isWinner)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0C000).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('GEWINNER', style: TextStyle(color: Color(0xFFF0C000), fontSize: 9)),
                              ),
                            if (isLocal)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text('DU', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 9)),
                              ),
                          ],
                        ),
                        Text(
                          hasPhoto
                              ? 'Foto gemacht ✓'
                              : 'KEIN FOTO — +$noPhotoPenalty Strafpunkte!',
                          style: TextStyle(
                            color: hasPhoto ? const Color(0xFF238636) : const Color(0xFFDA3633),
                            fontSize: 12,
                            fontWeight: hasPhoto ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),

          // ── Verlierer: Minuspunkte eingeben ────────────────────────────
          if (_winnerId != null) ...[
            Text(
              'Minuspunkte der Verlierer',
              style: TextStyle(
                color: _players.any((p) => p['player_id'] != _winnerId)
                    ? Colors.white
                    : const Color(0xFF8B949E),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ..._players.where((p) => p['player_id'] != _winnerId).map((p) {
              final pid = p['player_id'] as String? ?? '';
              final name = p['profiles']?['username'] ?? 'Unbekannt';
              final isLocal = pid == _localUserId;
              final isCifte = p['is_cifte'] as bool? ?? false;
              // Verlierer-Faktor = Tischfarbe × eigener Cifte
              final loserFactor = tableColorFactor(_tableColor) * (isCifte ? 2 : 1);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF30363D)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLocal)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF58A6FF).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('DU', style: TextStyle(color: Color(0xFF58A6FF), fontSize: 9)),
                                ),
                              if (isCifte)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0C000).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('Çifte', style: TextStyle(color: Color(0xFFF0C000), fontSize: 9)),
                                ),
                            ],
                          ),
                          Text(
                            'Basis × $loserFactor = ${(_penaltyInputs[pid] ?? 0) * loserFactor} Strafpunkte',
                            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: _controllers[pid],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          filled: true,
                          fillColor: const Color(0xFF21262D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF30363D)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _penaltyInputs[pid] = int.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // ── Ergebnis eintragen ─────────────────────────────────────────
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitResults,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Ergebnis eintragen${_missingPhotoCount > 0 ? ' (+${_missingPhotoCount * noPhotoPenalty} Strafpunkte für fehlende Fotos)' : ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: _endGame,
            child: const Text('Spiel beenden', style: TextStyle(color: Color(0xFF8B949E))),
          ),
        ],
      ),
    );
  }
}

// ─── Kamera Sheet — AI Vision Integration ──────────────────────────────────

/// _CameraSheet — Manual-First tile entry
///
/// App works 100% without M90q / Ollama / any network.
/// Manual entry is always the primary UX.
/// Camera scan is a BONUS available only when M90q proxy is configured.
///
/// Fallback chain (handled by VisionService):
///   M90q Ollama → Manual (no error shown to user)
class _CameraSheet extends StatefulWidget {
  final TileColor tableColor;
  final int gostergeNumber;
  final VisionService visionService;
  final ImagePicker imagePicker;
  final void Function(int basisPunkte) onAnalyseDone;

  const _CameraSheet({
    required this.tableColor,
    required this.gostergeNumber,
    required this.visionService,
    required this.imagePicker,
    required this.onAnalyseDone,
  });

  @override
  State<_CameraSheet> createState() => _CameraSheetState();
}

class _CameraSheetState extends State<_CameraSheet> {

  bool _isAnalysing = false;
  VisionResult? _result;
  int _manualCount = 0;     // user-editable basis points
  bool _triedCamera = false; // did user try the camera?

  int get _basisPunkte {
    // Prefer AI result; fall back to manual entry
    if (_result != null) return _result!.penaltyTiles.length;
    return _manualCount;
  }

  String get _modeLabel {
    if (_result == null) return 'Manuell';
    switch (_result!.mode) {
      case 'tflite': return 'TFLite (on-device)';
      case 'proxy':  return 'KI (M90q Ollama)';
      default:       return 'Manuell';
    }
  }

  // ── Camera ─────────────────────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final photo = await widget.imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() {
      _isAnalysing = true;
      _triedCamera = true;
      _result = null;
    });

    try {
      final gosterge = Tile(widget.tableColor, widget.gostergeNumber);
      final result = await widget.visionService.analyseRack(
        imagePath: photo.path,
        gosterge: gosterge,
        manualBasisPunkte: _manualCount,
      );
      if (mounted) {
        setState(() {
          _isAnalysing = false;
          _result = result;
          _manualCount = result.penaltyTiles.length;
        });
      }
    } catch (_) {
      // Proxy unreachable or Ollama error → silently falls back to manual
      if (mounted) {
        setState(() {
          _isAnalysing = false;
          _result = null; // stays in manual mode
        });
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF30363D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text(
            'Basis-Punkte eingeben',
            style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Wie viele Steine passen nicht in eine Reihe oder ein Paar?',
            style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
          ),
          const SizedBox(height: 24),

          // ── Manual counter (always visible, always works) ─────────────
          _buildManualCounter(),

          const SizedBox(height: 16),

          // ── Live preview ───────────────────────────────────────────────
          _buildPreview(),

          const SizedBox(height: 16),

          // ── Camera scan button (optional bonus) ───────────────────────
          if (!_triedCamera) ...[
            OutlinedButton.icon(
              onPressed: _takePhoto,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Kamera-Scan (optional)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF58A6FF),
                side: const BorderSide(color: Color(0xFF58A6FF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '📷 Kamera-Scan nutzt Ollama auf M90q (lokales WLAN).\nFunktioniert auch ohne — einfach Zahl eingeben.',
              style: TextStyle(color: Color(0xFF484F58), fontSize: 11),
            ),
          ] else if (_isAnalysing) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF58A6FF),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Ollama analysiert...',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                ],
              ),
            ),
          ] else ...[
            // Show result + option to re-take
            if (_result != null && _result!.mode == 'proxy') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF238636).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF238636)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFFF0C000), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KI erkannt: $_basisPunkte ungültige Steine',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _takePhoto,
                      child: const Text('Erneut',
                          style: TextStyle(color: Color(0xFF58A6FF), fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('Nochmal scannen'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8B949E),
                ),
              ),
            ],
          ],

          const SizedBox(height: 20),

          // ── Confirm ──────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B949E),
                    side: const BorderSide(color: Color(0xFF30363D)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Abbrechen'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onAnalyseDone(_basisPunkte);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Bestätigen: $_basisPunkte Basis-Punkte',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Manual stepper: -1 / count / +1
  Widget _buildManualCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.touch_app, color: Color(0xFF58A6FF), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Manuell eingeben',
                style: TextStyle(
                    color: Color(0xFF8B949E), fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_result != null && _result!.mode != 'manual')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0C000).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _modeLabel,
                    style: const TextStyle(
                        color: Color(0xFFF0C000), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _counterBtn(Icons.remove, () {
                if (_manualCount > 0) {
                  setState(() {
                    _manualCount--;
                    _result = null; // switch back to manual
                  });
                  widget.onAnalyseDone(_manualCount);
                }
              }),
              const SizedBox(width: 24),
              Column(
                children: [
                  Text(
                    '$_manualCount',
                    style: TextStyle(
                      color: _tileColor(widget.tableColor),
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Basis-Punkte',
                    style: TextStyle(color: const Color(0xFF8B949E), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              _counterBtn(Icons.add, () {
                if (_manualCount < 15) {
                  setState(() {
                    _manualCount++;
                    _result = null;
                  });
                  widget.onAnalyseDone(_manualCount);
                }
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '× ${tableColorFactor(widget.tableColor)} = ${_basisPunkte * tableColorFactor(widget.tableColor)} Strafpunkte',
            style: TextStyle(color: _tileColor(widget.tableColor), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildPreview() {
    final penalty = _basisPunkte * tableColorFactor(widget.tableColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _tileColor(widget.tableColor).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tileColor(widget.tableColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$_basisPunkte Steine × ${tableColorFactor(widget.tableColor)} = ',
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 14),
          ),
          Text(
            '$penalty Strafpunkte',
            style: TextStyle(
              color: _tileColor(widget.tableColor),
              fontWeight: FontWeight.bold, fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Color _tileColor(TileColor c) {
    switch (c) {
      case TileColor.yellow: return const Color(0xFFF0C000);
      case TileColor.blue:   return const Color(0xFF1F6FEB);
      case TileColor.red:    return const Color(0xFFDA3633);
      case TileColor.black:  return const Color(0xFF6E7681);
    }
  }
}

