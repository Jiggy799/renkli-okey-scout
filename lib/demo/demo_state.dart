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

  DemoPlayer({
    required this.id,
    required this.name,
    required this.seatIndex,
    this.isCifte = false,
    this.isHuman = false,
    this.cumulativePenalty = 0,
    this.penaltyBasis = 0,
    this.gostergeShowCount = 0,
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
  bool jokerFinish;

  DemoRound({
    required this.roundNumber,
    required this.tableColor,
    required this.gostergeTile,
    required this.jokerTile,
    this.gostergeShownBy,
    this.winnerId,
    this.jokerFinish = false,
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
  bool jokerFinish = false;
  List<DemoRound> rounds = [];
  String? gostergeShownBy; // who showed gösterge this round

  static const List<String> _fakeNames = [
    'Ali', 'Veli', 'Ayse', 'Fatma', 'Mehmet', 'Hakan',
    'Zeynep', 'Emre', 'Selin', 'Burak', 'Cem', 'Deniz',
  ];

  void init1Player() {
    playerCount = 1;
    currentRound = 1;
    jokerFinish = false;
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
    jokerFinish = false;
    rounds = [];
    gostergeShownBy = null;
    gostergeNumber = 13;

    players = [
      DemoPlayer(id: 'human_1', name: 'Spieler 1', seatIndex: 0, isHuman: true),
      DemoPlayer(id: 'ai_1',    name: _fakeNames[3], seatIndex: 1),
      DemoPlayer(id: 'human_2', name: 'Spieler 2', seatIndex: 2, isHuman: true),
      DemoPlayer(id: 'ai_3',    name: _fakeNames[4], seatIndex: 3),
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

  int liveFactorFor(DemoPlayer p) {
    return liveFactor(
      tableColor: selectedColor,
      jokerFinish: jokerFinish,
      playerCifte: p.isCifte,
    );
  }

  int calculatePenalty(DemoPlayer p) {
    if (p.penaltyBasis == 0) return 0;
    // jokerFinish und Cifte-Finish des Gewinners schlagen nur für
    // die VERLIERER auf — in der Demo ist calculatePenalty für alle
    // Verlierer, daher kein jokerFinish hier.
    return berechneStrafpunkte(
      basisPunkte: p.penaltyBasis,
      tableColor: selectedColor,
      playerCifteFactor: p.isCifte,
    );
  }

  void applyGostermeTo(String playerId) {
    final p = players.firstWhere((pl) => pl.id == playerId);
    final bonus = gostergeShowBonus(selectedColor); // negative, e.g. -20
    p.cumulativePenalty += bonus;
    p.gostergeShowCount++;
    gostergeShownBy = playerId;
  }

  void applyRoundEnd() {
    for (final p in players) {
      if (p.penaltyBasis > 0) {
        p.cumulativePenalty += calculatePenalty(p);
      }
    }

    rounds.add(DemoRound(
      roundNumber: currentRound,
      tableColor: selectedColor,
      gostergeTile: currentGostergeTile,
      jokerTile: currentJokerTile,
      gostergeShownBy: gostergeShownBy,
      jokerFinish: jokerFinish,
    ));

    currentRound++;
    _advanceGosterge();
    jokerFinish = false;
    gostergeShownBy = null;
    for (final p in players) {
      p.penaltyBasis = 0;
    }
  }

  void simulateAIPenalties() {
    final seed = DateTime.now().millisecondsSinceEpoch;
    for (final p in players) {
      if (!p.isHuman && p.penaltyBasis == 0) {
        p.penaltyBasis = ((seed + p.id.hashCode) % 25) + 1; // 1-25 stones
      }
    }
  }

  bool get isGameOver => currentRound > 11;

  int gostergeBonusFor(String playerId) {
    int total = 0;
    for (final r in rounds) {
      if (r.gostergeShownBy == playerId) {
        total += gostergeShowBonus(r.tableColor);
      }
    }
    return total;
  }

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
    jokerFinish = false;
    gostergeShownBy = null;
    gostergeNumber = 13;
  }
}
