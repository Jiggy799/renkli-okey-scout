// lib/utils/score_calculator.dart
// RenkliOkeyScout — Score & Penalty Math Engine

// ─── Tile model ────────────────────────────────────────────────────────────────

enum TileColor { yellow, blue, red, black }

class Tile {
  final TileColor color;
  final int number; // 1–13
  final bool isOkey; // wild card / false okey tag

  const Tile(this.color, this.number, [this.isOkey = false]);

  @override
  String toString() =>
      'Tile(${color.name},$number${isOkey ? ',ok' : ''})';

  @override
  bool operator ==(Object o) =>
      identical(this, o) ||
      o is Tile &&
          o.color == color &&
          o.number == number &&
          o.isOkey == isOkey;

  @override
  int get hashCode => Object.hash(color, number, isOkey);
}

// ─── Strafpunkte: kein Foto ─────────────────────────────────────────────────

/// Strafe wenn ein Spieler sein Rack NICHT fotografiert hat.
/// Alle müssen fotografieren — auch der Gewinner.
const int noPhotoPenalty = 100;

// ─── Gösterge / Table-Color multipliers ──────────────────────────────────────

/// Table colour factor (Gösterge multiplier).
int tableColorFactor(TileColor color) {
  switch (color) {
    case TileColor.yellow:
      return 2;
    case TileColor.blue:
      return 3;
    case TileColor.red:
      return 4;
    case TileColor.black:
      return 5;
  }
}

// ─── Core validation ─────────────────────────────────────────────────────────

/// Returns true when three or more tiles form a valid normal series.
/// Rule: 3+ consecutive numbers of the SAME colour.
/// Corner series: 12→13→1 is VALID, 13→1→2 is INVALID.
/// Joker tiles (isOkey) ARE wildcards — they fill exactly ONE missing gap in a series.
bool isValidSeries(List<Tile> tiles) {
  if (tiles.length < 3) return false;

  // Separate jokers from real tiles
  final jokers = tiles.where((t) => t.isOkey).toList();
  final real   = tiles.where((t) => !t.isOkey).toList();

  if (real.isEmpty) return true; // only jokers = valid
  if (real.length < 3 - jokers.length) return false; // not enough to form a series even with jokers

  // All real tiles must be same colour
  final farbe = real.first.color;
  if (real.any((t) => t.color != farbe)) return false;

  // Sort real tiles with corner wrap: 1 sorts after 13
  final sorted = List<Tile>.from(real)
    ..sort((a, b) {
      final an = a.number == 1 ? 14 : a.number;
      final bn = b.number == 1 ? 14 : b.number;
      return an.compareTo(bn);
    });

  // Build virtual sequence: 1 becomes 14 (so 13→1 wraps to 13→14)
  final virtual = sorted.map((t) => t.number == 1 ? 14 : t.number).toList()..sort();
  int jokerBudget = jokers.length;

  // 13→1→2 is forbidden: detect if 1 comes after 13 with 2 between them
  final hasOne = virtual.any((n) => n == 14);
  final hasThirteen = virtual.any((n) => n == 13);
  final hasTwo = virtual.any((n) => n == 2);
  if (hasOne && hasThirteen && hasTwo) {
    // If 13 is before 1 and 2 is between them: invalid
    final idx13 = sorted.indexWhere((t) => t.number == 13);
    final idx1  = sorted.indexWhere((t) => t.number == 1);
    final idx2  = sorted.indexWhere((t) => t.number == 2);
    if (idx13 >= 0 && idx1 >= 0 && idx2 >= 0 && idx13 < idx1 && idx2 > idx13) {
      return false; // 13→1→2 pattern
    }
  }

  // Check consecutive gaps, using jokers to fill
  for (int i = 0; i < virtual.length - 1; i++) {
    final gap = virtual[i + 1] - virtual[i];
    if (gap == 1) continue;    // consecutive ✓
    if (gap == 0) return false; // duplicate
    // gap > 1: needs jokers
    if (gap - 1 <= jokerBudget) {
      jokerBudget -= (gap - 1);
      continue;
    }
    return false; // gap too large for available jokers
  }

  return true;
}

/// Returns true when 3+ tiles are the same number, different colours.
/// This is the only valid "pair" type in NORMAL play.
/// In Çifte mode, 2-tile same-number-different-colour also counts as a pair.
bool isValidTriplet(List<Tile> tiles) {
  if (tiles.length < 3) return false;
  final first = tiles[0];
  if (first.isOkey) return false;
  return tiles.every((t) =>
      !t.isOkey && t.number == first.number && t.color != first.color);
}

/// NORMAL play: counts how many tiles form VALID groups.
/// Valid groups = series OR triplets only. Pairs are NOT counted.
/// Returns the number of UNGROUPED (penalty) tiles.
int countUngroupedTilesNormal(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;

  final available = List<Tile>.from(tiles);

  // greedily remove valid series
  bool removed;
  do {
    removed = false;
    for (int len = available.length; len >= 3; len--) {
      for (int start = 0; start <= available.length - len; start++) {
        final subset = available.sublist(start, start + len);
        if (isValidSeries(subset)) {
          available.removeRange(start, start + len);
          removed = true;
          break;
        }
      }
      if (removed) break;
    }
  } while (removed);

  // remove valid triplets
  do {
    removed = false;
    for (int len = available.length; len >= 3; len--) {
      for (int start = 0; start <= available.length - len; start++) {
        final subset = available.sublist(start, start + len);
        if (isValidTriplet(subset)) {
          available.removeRange(start, start + len);
          removed = true;
          break;
        }
      }
      if (removed) break;
    }
  } while (removed);

  return available.length;
}

/// ÇİFTE play: ZWEI gültige Varianten:
/// Variante 1: EXAKT 7 Paare (alle 14 Steine = 7 Doppel-Paare) — 0 Schrott
/// Variante 2: EXAKT 5 Paare + 1 Reihe von genau 4 Steinen.
/// Ein Paar = 2× gleiche Zahl, gleiche Farbe (identische Steine).
/// Joker (isOkey) zählen NICHT in Paaren.
/// Variante 1 wird priorisiert (wenn 7 Paare möglich → gültig).
bool isValidCifteSet(List<Tile> tiles) {
  if (tiles.length != 14) return false;

  // Variante 1: Versuche 7 Doppel-Paare zu bilden
  // Ein Paar = gleiche Farbe + gleiche Zahl (identische Steine)
  // Joker (isOkey) können nicht in Paaren verwendet werden.
  final nonJokers = tiles.where((t) => !t.isOkey).toList();
  int pairsFound = 0;
  final remaining = List<Tile>.from(nonJokers);

  for (int i = 0; i < remaining.length - 1 && pairsFound < 7; i++) {
    for (int j = i + 1; j < remaining.length && pairsFound < 7; j++) {
      if (remaining[i].number == remaining[j].number &&
          remaining[i].color == remaining[j].color) {
        // Paar gefunden
        pairsFound++;
        remaining.removeAt(j);
        remaining.removeAt(i);
        break;
      }
    }
  }

  if (pairsFound == 7 && remaining.isEmpty) {
    return true; // Variante 1: 7 Doppel-Paare ✓
  }

  // Variante 2: 5 Paare + 4er-Serie
  return countUngroupedTilesCifte(tiles) == 0;
}

/// Zählt die ungruppierten Steine für ÇİFTE.
/// Variante 1: 7 Doppel-Paare (alle 14 Steine = 0 Schrott)
/// Variante 2: 5 Paare (gleiche Farbe+Zahl) + 4er-Serie (eine Farbe).
/// Joker (isOkey) können die Serie als Wildcard vervollständigen.
int countUngroupedTilesCifte(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;
  final available = List<Tile>.from(tiles);

  // Schritt 1: Versuche 4er-Serie mit Joker-Wildcards zu entfernen
  bool removedSeries = false;
  for (int len = 4; len >= 4 && !removedSeries; len--) {
    for (int start = 0; start <= available.length - len; start++) {
      final subset = available.sublist(start, start + len);
      if (isValidSeries(subset)) {
        available.removeRange(start, start + len);
        removedSeries = true;
        break;
      }
    }
  }

  // Schritt 2: Versuche 5 Paare zu entfernen (gleiche Farbe + Zahl)
  // Joker können nicht in Paaren verwendet werden.
  int pairsRemoved = 0;
  for (int i = 0; i < available.length - 1 && pairsRemoved < 5; i++) {
    for (int j = i + 1; j < available.length && pairsRemoved < 5; j++) {
      if (available[i].number == available[j].number &&
          available[i].color == available[j].color &&
          !available[i].isOkey &&
          !available[j].isOkey) {
        final hi = j;
        final lo = i;
        available.removeAt(hi);
        available.removeAt(lo);
        pairsRemoved++;
        break;
      }
    }
  }

  return available.length;
}

// ─── Okey/False-Okey helpers ─────────────────────────────────────────────────

/// In a real game the gösterge tile is passed in; here we expose the
/// canonical map so callers can tag wildcards correctly.
Tile makeOkeyTile(Tile gosterge) =>
    Tile(gosterge.color, gosterge.number, true);

Tile makeFalseOkey(Tile gosterge) =>
    Tile(gosterge.color, gosterge.number == 13 ? 1 : gosterge.number + 1, true);

// ─── Main scoring entry points ───────────────────────────────────────────────

/// Full penalty calculation for a player who lost the round.
///
/// Parameters:
///   basisPunkte      — sum of tile-values NOT forming valid series/pairs
///   tableColor       — Gösterge colour
///   jokerFinish     — winner discarded Okey tile (Joker Finish → ×2)
///   playerCifteFactor — this player's own Cifte flag (only applies to their own penalty)
int berechneStrafpunkte({
  required int basisPunkte,
  required TileColor tableColor,
  bool jokerFinish = false,
  bool playerCifteFactor = false,
}) {
  if (basisPunkte <= 0) return 0;

  // Tischfarbe × Spieler-Cifte (nur für diesen Spieler).
  // Joker-Finish (×2) und Cifte-Finish (×2) des GEWINNERS
  // werden AUSSCHLIESSLICH hier in liveFactor() für die Anzeige verwendet.
  // Die Verlierer-Strafe wird hier direkt berechnet:
  // ×Cifte nur wenn dieser spezielle Spieler Cifte hatte.
  int factor = tableColorFactor(tableColor);
  if (playerCifteFactor) factor *= 2; // eigener Cifte-Faktor

  return basisPunkte * factor;
}

/// Live-Faktor für die UI-Anzeige.
/// Joker-Finish (×2) und Cifte (×2) beziehen sich auf den GEWINNER,
/// nicht auf den individuellen Spieler.
int liveFactor({
  required TileColor tableColor,
  bool jokerFinish = false,
  bool playerCifte = false,
}) {
  int f = tableColorFactor(tableColor);
  if (jokerFinish) f *= 2; // Joker Finish ×2 (vom Gewinner)
  if (playerCifte) f *= 2; // Cifte ×2 (vom Gewinner — zeigt dass es Cifte-Win war)
  return f;
}

/// Gösterme Variante B (Belohnungs-Methode):
/// Der Spieler DER den Gösterge hält, bekommt MINUS-Punkte in Höhe von tableColorFactor.
int berechneGostermeStrafeHalter(TileColor tableColor) {
  return -tableColorFactor(tableColor); // negativ → wird vom Penalty abgezogen
}

/// Legacy-Alias für Gösterme Variante A (andere Methode):
/// Alle 3 Gegner bekommen +tableColorFactor. Der Zeigende bekommt 0.
int berechneGostermeStrafe(TileColor tableColor) {
  return tableColorFactor(tableColor);
}

/// Çifte Gitmek pair-count requirement.
/// Normally 7 pairs needed. When Çifte Gitmek is active and player loses,
/// only 5 pairs are required; the remaining 4 tiles must form a normal series.
int cifteRequiredPairs({bool isCifte = false}) => isCifte ? 5 : 7;

int cifteExtraTiles({bool isCifte = false}) => isCifte ? 4 : 0;

// ─── System B: Gösterge-Bonus (Minuspunkte fürs Zeigen) ──────────────────────

/// Gösterge-Bonus (System B) — Minuspunkte fürs Zeigen des Gösterge.
/// Über 11 Runden gesammelt, am Ende vom Gesamt-Penalty abziehen.
int gostergeShowBonus(TileColor color) {
  switch (color) {
    case TileColor.yellow: return 20; // Gelb = 20 Minuspunkte
    case TileColor.blue:   return 30; // Blau = 30 Minuspunkte
    case TileColor.red:    return 40; // Rot = 40 Minuspunkte
    case TileColor.black:  return 50; // Schwarz = 50 Minuspunkte
  }
}
