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
/// Joker tiles (isOkey) do NOT count as wildcards here — they must match colour.
bool isValidSeries(List<Tile> tiles) {
  if (tiles.length < 3) return false;
  // sort by number, with corner wrap: treat 1 after 13
  final sorted = List<Tile>.from(tiles)
    ..sort((a, b) {
      final an = a.number == 1 ? 14 : a.number;
      final bn = b.number == 1 ? 14 : b.number;
      return an.compareTo(bn);
    });

  // all must be same colour (wildcards excluded from series)
  if (sorted.any((t) => t.color != tiles.first.color || t.isOkey)) return false;

  for (int i = 0; i < sorted.length - 1; i++) {
    final cur = sorted[i].number == 1 ? 14 : sorted[i].number;
    final nxt = sorted[i + 1].number == 1 ? 14 : sorted[i + 1].number;
    if (nxt - cur != 1) return false;
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

/// ÇİFTE play: pairs are allowed (including same-colour pairs).
/// Minimum: 5 pairs + 1 series of exactly 4 tiles.
bool isValidCifteSet(List<Tile> tiles) {
  if (tiles.length != 6) return false; // 5 pairs = 10 tiles, but we check per-group

  // For simplicity: at least 5 pairs of any kind + 1 series of 4
  // Count pairs (2 same-number, different colours)
  int pairCount = 0;
  int seriesCount = 0;

  // Build all combinations
  for (int i = 0; i < tiles.length; i++) {
    for (int j = i + 1; j < tiles.length; j++) {
      if (tiles[i].number == tiles[j].number &&
          !tiles[i].isOkey &&
          !tiles[j].isOkey &&
          tiles[i].color != tiles[j].color) {
        pairCount++;
      }
    }
  }

  // Series of 4
  for (int start = 0; start <= tiles.length - 4; start++) {
    if (isValidSeries(tiles.sublist(start, start + 4))) {
      seriesCount++;
    }
  }

  return pairCount >= 5 && seriesCount >= 1;
}

/// Counts ungrouped tiles for ÇİFTE mode.
/// Same-color pairs ARE valid here.
int countUngroupedTilesCifte(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;
  final available = List<Tile>.from(tiles);

  // Remove valid series first
  bool removed;
  do {
    removed = false;
    for (int start = 0; start <= available.length - 3; start++) {
      final subset = available.sublist(start, start + 3);
      if (isValidSeries(subset)) {
        available.removeRange(start, start + 3);
        removed = true;
        break;
      }
    }
  } while (removed);

  // Remove valid triplets
  do {
    removed = false;
    for (int start = 0; start <= available.length - 3; start++) {
      final subset = available.sublist(start, start + 3);
      if (isValidTriplet(subset)) {
        available.removeRange(start, start + 3);
        removed = true;
        break;
      }
    }
  } while (removed);

  // Remove valid pairs (same number, different colour) — Çifte only
  do {
    removed = false;
    for (int i = 0; i < available.length - 1; i++) {
      for (int j = i + 1; j < available.length; j++) {
        if (available[i].number == available[j].number &&
            !available[i].isOkey &&
            !available[j].isOkey &&
            available[i].color != available[j].color) {
          available.removeAt(j);
          available.removeAt(i);
          removed = true;
          break;
        }
      }
      if (removed) break;
    }
  } while (removed);

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
///   jokerFinish     — winner discarded Okey tile (Joker Finish → x2)
///   isCifte         — player had Çifte Gitmek active
///   playerCifteFactor — player's own Çifte flag (x2 if active)
int berechneStrafpunkte({
  required int basisPunkte,
  required TileColor tableColor,
  bool jokerFinish = false,
  bool isCifte = false,
  bool playerCifteFactor = false,
}) {
  if (basisPunkte <= 0) return 0;

  // Tischfarbe × JokerFinish(×2) × Çifte(×2). Joker+Çifte Kombination = ×4 auf Tischfarbe
  int factor = tableColorFactor(tableColor);
  if (jokerFinish) factor *= 2; // Joker Finish = ×2
  if (isCifte) factor *= 2;      // Çifte = ×2
  // Joker + Çifte gleichzeitig: ×2 × ×2 = ×4 (oben kumuliert, korrekt)

  return basisPunkte * factor;
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

// ─── Live factor preview ─────────────────────────────────────────────────────

/// Returns the CURRENT multiplier for a given player given all conditions.
/// Used by the UI to show live factor in player cards.
int liveFactor({
  required TileColor tableColor,
  bool jokerFinish = false,
  bool playerCifte = false,
}) {
  int f = tableColorFactor(tableColor);
  if (jokerFinish) f *= 2;
  if (playerCifte) f *= 2;
  return f;
}
