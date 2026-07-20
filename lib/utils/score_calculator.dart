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

  // Corner rule: 12→13→1 is VALID, 13→1→2 is INVALID
  // 1 is treated as 14 for sorting, but we reject a 1 following a 13
  // (that's the invalid 13→1 transition)
  for (int i = 0; i < sorted.length - 1; i++) {
    final cur = sorted[i];
    final nxt = sorted[i + 1];
    final curNorm = cur.number == 1 ? 14 : cur.number;
    final nxtNorm = nxt.number == 1 ? 14 : nxt.number;
    if (nxtNorm - curNorm == 1) continue; // normal consecutive: OK
    // Reject 1 following 13 (13→1→2 pattern)
    if (cur.number == 13 && nxt.number == 1) return false;
    return false;
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

/// ÇİFTE play: EXAKT 5 Paare + 1 Reihe von genau 4 Steinen.
/// Ein Paar = 2× gleiche Zahl, verschiedene Farben (identische Steine verboten).
/// Paare MÜSSEN absolut identisch sein (z.B. Rot3 + Schwarz3).
/// Die restlichen 4 Steine müssen eine gültige Reihe in DERSELBEN Farbe bilden.
bool isValidCifteSet(List<Tile> tiles) {
  if (tiles.length != 14) return false;

  // ── Schritt 1: Finde 5 exakte Paare (gleiche Zahl, gleiche Farbe) ──
  // Ein Paar besteht aus 2 KACHELN (nicht 2 Steine):
  // Echte Steine: 4 Farben × 13 Zahlen = 52 Steine
  // In Cifte: Gleiche Zahl UND gleiche Farbe = identisches Paar
  // Da wir pro Farbe/Zahl nur max 2 echte Steine haben können,
  // ist ein Paar: 2 Kacheln derselben Farbe+Zahl.
  //
  // Praktisch für die UI-Eingabe: Der Spieler tippt 5 Paar-Nummern ein.
  // Hier prüfen wir nur ob die Serie aus 4 Steinen einer Farbe besteht.
  // Das tatsächliche Cifte-Set wird in countUngroupedTilesCifte geprüft.

  return countUngroupedTilesCifte(tiles) == 0;
}

/// Zählt die ungruppierten Steine für ÇİFTE.
/// Gültig = 5 Paare (jedes Paar: gleiche Zahl, gleiche Farbe = identisch)
/// + 1 Serie aus 4 Steinen IN EINER FARBE.
/// Çifte mit Joker: Joker zählt als gültig für die Serie.
int countUngroupedTilesCifte(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;
  final available = List<Tile>.from(tiles);

  // ── Joker identifizieren (Gösterge+1, oder False Okey) ──
  // Joker können in der Serie mitspielen aber nicht als Paar.
  // Hier vereinfacht: Joker werden als wildcard behandelt.

  // Schritt 1: Versuche 1 Serie aus 4 Steinen zu entfernen
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

  // Schritt 2: Versuche 5 Paare zu entfernen
  // Ein Paar = 2 identische Steine (gleiche Farbe + Zahl)
  // Joker (isOkey) können nicht in Paaren verwendet werden.
  int pairsRemoved = 0;
  for (int i = 0; i < available.length - 1 && pairsRemoved < 5; i++) {
    for (int j = i + 1; j < available.length && pairsRemoved < 5; j++) {
      if (available[i].number == available[j].number &&
          available[i].color == available[j].color &&
          !available[i].isOkey &&
          !available[j].isOkey) {
        // Paar gefunden: entferne höhere Index zuerst
        final hi = j;
        final lo = i;
        available.removeAt(hi);
        available.removeAt(lo);
        pairsRemoved++;
        break;
      }
    }
  }

  // Nach Serie(4) + 5 Paare(10) = 14 Steine, sollte available leer sein
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
