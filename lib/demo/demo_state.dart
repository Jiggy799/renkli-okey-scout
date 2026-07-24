// lib/demo/demo_state.dart
// RenkliOkeyScout — In-memory demo state (no Supabase needed)
// Used for 1-player and 2-player demo testing

import '../utils/score_calculator.dart';

// ─── Demo Player ─────────────────────────────────────────────────────────────

class DemoPlayer {
  final String id;
  final String name;
  final int seatIndex;
  bool isCifte;
  bool isHuman;
  int cumulativePenalty;
  int penaltyBasis; // stone sum entered for current round
  int gostergeShowCount; // System B
  bool photoSubmitted; // System A: no-photo penalty

  DemoPlayer({
    required this.id,
    required this.name,
    required this.seatIndex,
    this.isCifte = false,
    this.isHuman = false,
    this.cumulativePenalty = 0,
    this.penaltyBasis = 0,
    this.gostergeShowCount = 0,
    this.photoSubmitted = false,
  });
}

// ─── Demo Round ─────────────────────────────────────────────────────────────

class DemoRound {
  final int roundNumber;
  TileColor tableColor;
  Tile gostergeTile;
  Tile jokerTile;
  String? gostergeShownBy;
  String? winnerId;
  WinType winType;

  DemoRound({
    required this.roundNumber,
    required this.tableColor,
    required this.gostergeTile,
    required this.jokerTile,
    this.gostergeShownBy,
    this.winnerId,
    this.winType = WinType.normal,
  });
}

// ─── Demo State (singleton) ─────────────────────────────────────────────────

class DemoState {
  static final DemoState _instance = DemoState._internal();
  factory DemoState() => _instance;
  DemoState._internal();

  int playerCount = 0; // 1 or 2
  List<DemoPlayer> players = [];
  int currentRound = 1;
  TileColor selectedColor = TileColor.yellow;
  int gostergeNumber = 13;
  WinType winType = WinType.normal;
  List<DemoRound> rounds = [];
  String? gostergeShownBy; // who showed gösterge this round

  static const List<String> _fakeNames = [
    'Ceyhan', 'Tugrul', 'Hakan', 'Ömer',
  ];

  void init1Player() {
    playerCount = 1;
    currentRound = 1;
    winType = WinType.normal;
    rounds = [];
    gostergeShownBy = null;
    gostergeNumber = 13;

    players = [
      DemoPlayer(id: 'human',   name: 'Du',        seatIndex: 0, isHuman: true),
      DemoPlayer(id: 'ai_1',   name: _fakeNames[0], seatIndex: 1),
      DemoPlayer(id: 'ai_2',   name: _fakeNames[1], seatIndex: 2),
      DemoPlayer(id: 'ai_3',   name: _fakeNames[2], seatIndex: 3),
    ];
  }

  void init2Players() {
    playerCount = 2;
    currentRound = 1;
    winType = WinType.normal;
    rounds = [];
    gostergeShownBy = null;
    gostergeNumber = 13;

    players = [
      DemoPlayer(id: 'human_1', name: 'Spieler 1', seatIndex: 0, isHuman: true),
      DemoPlayer(id: 'ai_1',    name: _fakeNames[1], seatIndex: 1),
      DemoPlayer(id: 'human_2', name: 'Spieler 2', seatIndex: 2, isHuman: true),
      DemoPlayer(id: 'ai_3',    name: _fakeNames[2], seatIndex: 3),
    ];
  }

  void _advanceGosterge() {
    gostergeNumber = gostergeNumber > 1 ? gostergeNumber - 1 : 13;
  }

  Tile get currentGostergeTile => Tile(selectedColor, gostergeNumber);

  Tile get currentJokerTile {
    int j = gostergeNumber + 1;
    if (j > 13) j = 1;
    return Tile(selectedColor, j);
  }

  int get tableFactor => tableColorFactor(selectedColor);

  /// Live-Faktor für die UI-Anzeige.
  int liveFactorFor(DemoPlayer p) {
    // Joker/Cifte Multiplikatoren kommen vom Gewinner.
    // isCifte wird hier nicht aufgeschlagen — nur Joker Finish ×2.
    return liveFactor(
      tableColor: selectedColor,
      winType: winType,
    );
  }

  /// Berechnet die Strafpunkte für einen Verlierer.
  /// Joker-Multiplikator kommt vom Gewinner (winType).
  int calculatePenalty(DemoPlayer p) {
    if (p.penaltyBasis == 0) return 0;
    return berechneStrafpunkte(
      basisPunkte: p.penaltyBasis,
      tableColor: selectedColor,
      winType: winType,
    );
  }

  /// Gösterge-Variante A: Der Zeigende bekommt 0,
  /// alle anderen bekommen +tableColorFactor.
  void applyGostermeTo(String playerId) {
    gostergeShownBy = playerId;
    // Finder bekommt nichts, andere bekommen +color
    // (wird in applyRoundEnd verarbeitet)
  }

  void applyRoundEnd() {
    for (final p in players) {
      // No-photo penalty: +100
      if (!p.photoSubmitted) {
        p.cumulativePenalty += noPhotoPenalty;
      }
      if (p.penaltyBasis > 0) {
        p.cumulativePenalty += calculatePenalty(p);
      }
      // Reset per-round state
      p.penaltyBasis = 0;
      p.isCifte = false;
      p.photoSubmitted = false;
    }

    // Gösterge-Zeigen: Nur der ZEICHER bekommt den Bonus (-Farbwert × 10).
    // Zeitpunkt: Nur DIREKT nach dem Austeilen, vor dem ersten Zug.
    // Endabrechnung: ΣSystemA − ΣGöstergeBonus
    if (gostergeShownBy != null) {
      final finder = players.firstWhere((p) => p.id == gostergeShownBy);
      finder.gostergeShowCount++;
      // Bonus = negativ (gut für den Spieler)
      finder.cumulativePenalty += berechneGostermeBonus(selectedColor);
    }

    rounds.add(DemoRound(
      roundNumber: currentRound,
      tableColor: selectedColor,
      gostergeTile: currentGostergeTile,
      jokerTile: currentJokerTile,
      gostergeShownBy: gostergeShownBy,
      winType: winType,
    ));

    currentRound++;
    _advanceGosterge();
    winType = WinType.normal;
    gostergeShownBy = null;
  }

  void simulateAIPenalties() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    for (final p in players) {
      if (!p.isHuman && p.penaltyBasis == 0) {
        p.penaltyBasis = ((seed + p.id.hashCode) % 25) + 1;
      }
    }
  }

  bool get isGameOver => currentRound > 11;

  /// Summe aller Gösterge-Boni (System B).
  /// Bonus = negativ (reduziert Endabrechnung).
  int gostergeBonusFor(String playerId) {
    int total = 0;
    for (final r in rounds) {
      if (r.gostergeShownBy == playerId) {
        total += berechneGostermeBonus(r.tableColor);
      }
    }
    return total;
  }

  /// Final-Stand: ΣSystemA − ΣGöstergeBonus
  int finalPenaltyFor(String playerId) {
    final p = players.firstWhere((pl) => pl.id == playerId);
    return p.cumulativePenalty - gostergeBonusFor(playerId);
  }

  List<DemoPlayer> get sortedByPenalty {
    final sorted = List<DemoPlayer>.from(players);
    sorted.sort((a, b) => finalPenaltyFor(a.id).compareTo(finalPenaltyFor(b.id)));
    return sorted;
  }

  void reset() {
    players = [];
    rounds = [];
    currentRound = 1;
    winType = WinType.normal;
    gostergeShownBy = null;
    gostergeNumber = 13;
    selectedColor = TileColor.yellow;
  }
}
