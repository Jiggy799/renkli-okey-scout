// lib/services/demo_persistence.dart
// RenkliOkeyScout — DemoState Persistenz via SharedPreferences
//
// Speichert DemoState zwischen App-Restarts.
// Anti-Cheat: User-Edits werden separat geloggt.
//
// Perplexity Best Practice: "Prefer offline-first persistence with local, structured storage"

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/demo_state.dart';
import '../utils/score_calculator.dart';

class DemoPersistence {
  static const _key = 'demo_state_v1';

  /// Speichere DemoState in SharedPreferences
  static Future<void> save(DemoState state) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _stateToJson(state);
    await prefs.setString(_key, jsonEncode(json));
  }

  /// Lade DemoState aus SharedPreferences
  static Future<DemoState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return null;

    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final state = _jsonToState(data);
      return state;
    } catch (e) {
      debugPrint('[DemoPersistence] Load failed: $e');
      return null;
    }
  }

  /// Reset (alle Daten löschen)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ─── JSON-Serialisierung ───────────────────────────────────────────────

  static Map<String, dynamic> _stateToJson(DemoState s) {
    return {
      'playerCount': s.playerCount,
      'currentRound': s.currentRound,
      'selectedColor': s.selectedColor.name,
      'gostergeNumber': s.gostergeNumber,
      'winType': s.winType.name,
      'gostergeShownBy': s.gostergeShownBy,
      'players': s.players.map((p) => {
        'id': p.id,
        'name': p.name,
        'seatIndex': p.seatIndex,
        'isCifte': p.isCifte,
        'isHuman': p.isHuman,
        'isWinner': p.isWinner,
        'isJokerFinish': p.isJokerFinish,
        'cumulativePenalty': p.cumulativePenalty,
        'schrottTiles': p.schrottTiles.map((t) => {
          'color': t.color.name,
          'number': t.number,
        }).toList(),
        'gostergeShowCount': p.gostergeShowCount,
        'photoSubmitted': p.photoSubmitted,
      }).toList(),
      'rounds': s.rounds.map((r) => {
        'roundNumber': r.roundNumber,
        'tableColor': r.tableColor.name,
        'gostergeNumber': r.gostergeTile.number,
        'jokerNumber': r.jokerTile.number,
        'gostergeShownBy': r.gostergeShownBy,
        'winnerId': r.winnerId,
        'winType': r.winType.name,
      }).toList(),
    };
  }

  static DemoState _jsonToState(Map<String, dynamic> json) {
    final s = DemoState();

    s.playerCount = json['playerCount'] as int? ?? 0;
    s.currentRound = json['currentRound'] as int? ?? 1;
    s.selectedColor = TileColor.values.firstWhere(
      (c) => c.name == json['selectedColor'],
      orElse: () => TileColor.yellow,
    );
    s.gostergeNumber = json['gostergeNumber'] as int? ?? 13;
    s.winType = WinType.values.firstWhere(
      (w) => w.name == json['winType'],
      orElse: () => WinType.normal,
    );
    s.gostergeShownBy = json['gostergeShownBy'] as String?;

    // Players
    final playersJson = json['players'] as List<dynamic>? ?? [];
    s.players = playersJson.map((p) {
      final player = DemoPlayer(
        id: p['id'] as String,
        name: p['name'] as String,
        seatIndex: p['seatIndex'] as int? ?? 0,
      );
      player.isCifte = p['isCifte'] as bool? ?? false;
      player.isHuman = p['isHuman'] as bool? ?? false;
      player.isWinner = p['isWinner'] as bool? ?? false;
      player.isJokerFinish = p['isJokerFinish'] as bool? ?? false;
      player.cumulativePenalty = p['cumulativePenalty'] as int? ?? 0;
      player.gostergeShowCount = p['gostergeShowCount'] as int? ?? 0;
      player.photoSubmitted = p['photoSubmitted'] as bool? ?? false;
      player.schrottTiles = (p['schrottTiles'] as List<dynamic>? ?? [])
        .map((t) => Tile(
            TileColor.values.firstWhere(
              (c) => c.name == t['color'],
              orElse: () => TileColor.yellow,
            ),
            t['number'] as int))
        .toList();
      return player;
    }).toList();

    // Rounds (history)
    final roundsJson = json['rounds'] as List<dynamic>? ?? [];
    s.rounds = roundsJson.map((r) {
      return DemoRound(
        roundNumber: r['roundNumber'] as int,
        tableColor: TileColor.values.firstWhere(
          (c) => c.name == r['tableColor'],
          orElse: () => TileColor.yellow,
        ),
        gostergeTile: Tile(
          TileColor.values.firstWhere(
            (c) => c.name == r['tableColor'],
            orElse: () => TileColor.yellow,
          ),
          r['gostergeNumber'] as int? ?? 1,
        ),
        jokerTile: Tile(
          TileColor.values.firstWhere(
            (c) => c.name == r['tableColor'],
            orElse: () => TileColor.yellow,
          ),
          r['jokerNumber'] as int? ?? 2,
        ),
        gostergeShownBy: r['gostergeShownBy'] as String?,
        winnerId: r['winnerId'] as String?,
        winType: WinType.values.firstWhere(
          (w) => w.name == r['winType'],
          orElse: () => WinType.normal,
        ),
      );
    }).toList();

    return s;
  }
}

// Debug print helper
void debugPrint(String s) {
  // ignore: avoid_print
  print(s);
}
