// lib/utils/score_calculator.dart
// RenkliOkeyScout — Score & Penalty Math Engine
//
// Regeln (Stand: Juli 2026):
//   Gelb×2 | Blau×3 | Rot×4 | Schwarz×5
//   Joker ×2 | Çifte ×2 | Beides = ×4 (max ×20)
//   12→13→1 ✓ | 13→1→2 ✗
//   Kein Foto = +100
//   Gösterge Variante A: others +color | Variante B: halter -color

// ─── Tile model ────────────────────────────────────────────────────────────────

enum TileColor { yellow, blue, red, black }

enum WinType {
  /// Normaler Sieg
  normal,
  /// Gewinner hat Okey abgelegt → ×2
  okey,
  /// Gewinner hat Çifte gewählt → ×2
  cifte,
  /// Gewinner hat Okey UND Çifte → ×4
  okeyCifte,
}

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

// ─── Constants ────────────────────────────────────────────────────────────────

/// Strafe wenn kein Foto hochgeladen wurde.
const int noPhotoPenalty = 100;

/// Tischfarbe → Multiplikator (Gösterge-Faktor).
int tableColorFactor(TileColor color) {
  switch (color) {
    case TileColor.yellow: return 2;
    case TileColor.blue:   return 3;
    case TileColor.red:    return 4;
    case TileColor.black:  return 5;
  }
}

// ─── Core validation ─────────────────────────────────────────────────────────

/// Returns true when three or more tiles form a valid normal series.
/// Rule: 3+ consecutive numbers of the SAME colour.
/// Corner series: 12→13→1 is VALID, 13→1→2 is INVALID.
/// Joker tiles (isOkey) fill exactly ONE missing gap in a series.
bool isValidSeries(List<Tile> tiles) {
  if (tiles.length < 3) return false;

  final jokers = tiles.where((t) => t.isOkey).toList();
  final real   = tiles.where((t) => !t.isOkey).toList();

  if (real.isEmpty) return true;
  if (real.length < 3 - jokers.length) return false;

  final farbe = real.first.color;
  if (real.any((t) => t.color != farbe)) return false;

  // Sort with corner wrap: 1 sorts after 13 (virtual: 1 → 14)
  final sorted = List<Tile>.from(real)
    ..sort((a, b) {
      final an = a.number == 1 ? 14 : a.number;
      final bn = b.number == 1 ? 14 : b.number;
      return an.compareTo(bn);
    });

  final virtual = sorted.map((t) => t.number == 1 ? 14 : t.number).toList()..sort();
  int jokerBudget = jokers.length;

  // 13→1→2 forbidden: detect 13 before 1 with 2 between
  final hasOne      = virtual.any((n) => n == 14);
  final hasThirteen = virtual.any((n) => n == 13);
  final hasTwo       = virtual.any((n) => n == 2);
  if (hasOne && hasThirteen && hasTwo) {
    final idx13 = sorted.indexWhere((t) => t.number == 13);
    final idx1  = sorted.indexWhere((t) => t.number == 1);
    final idx2  = sorted.indexWhere((t) => t.number == 2);
    if (idx13 >= 0 && idx1 >= 0 && idx2 >= 0 && idx13 < idx1 && idx2 > idx13) {
      return false; // 13→1→2 pattern
    }
  }

  for (int i = 0; i < virtual.length - 1; i++) {
    final gap = virtual[i + 1] - virtual[i];
    if (gap == 1)   continue;
    if (gap == 0)   return false;
    if (gap - 1 <= jokerBudget) {
      jokerBudget -= (gap - 1);
      continue;
    }
    return false;
  }
  return true;
}

/// Returns true when 3+ tiles are same number, different colours.
bool isValidTriplet(List<Tile> tiles) {
  if (tiles.length < 3) return false;
  final first = tiles[0];
  if (first.isOkey) return false;
  return tiles.every((t) =>
      !t.isOkey && t.number == first.number && t.color != first.color);
}

/// Counts ungrouped tiles in NORMAL play.
/// Valid groups = series OR triplets only.
int countUngroupedTilesNormal(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;
  final available = List<Tile>.from(tiles);

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

/// ÇİFTE — ZWEI gültige Varianten:
/// Variante 1: EXAKT 7 Doppel-Paare (alle 14 Steine) → 0 Schrott
/// Variante 2: EXAKT 5 Paare + 1 Reihe von genau 4 Steinen (Joker erlaubt)
bool isValidCifteSet(List<Tile> tiles) {
  if (tiles.length != 14) return false;

  final nonJokers = tiles.where((t) => !t.isOkey).toList();
  int pairsFound = 0;
  final remaining = List<Tile>.from(nonJokers);

  for (int i = 0; i < remaining.length - 1 && pairsFound < 7; i++) {
    for (int j = i + 1; j < remaining.length && pairsFound < 7; j++) {
      if (remaining[i].number == remaining[j].number &&
          remaining[i].color == remaining[j].color) {
        pairsFound++;
        remaining.removeAt(j);
        remaining.removeAt(i);
        break;
      }
    }
  }

  if (pairsFound == 7 && remaining.isEmpty) return true; // Variante 1 ✓
  return countUngroupedTilesCifte(tiles) == 0;              // Variante 2
}

/// Count ungrouped tiles for ÇİFTE.
/// Variante 1: 7 Doppel-Paare → 0
/// Variante 2: 5 Paare + 4er-Serie (Joker erlaubt in Serie)
int countUngroupedTilesCifte(List<Tile> tiles) {
  if (tiles.isEmpty) return 0;
  final available = List<Tile>.from(tiles);

  // Try to remove a 4-tile series (jokers allowed)
  bool removedSeries = false;
  for (int start = 0; start <= available.length - 4; start++) {
    final subset = available.sublist(start, start + 4);
    if (isValidSeries(subset)) {
      available.removeRange(start, start + 4);
      removedSeries = true;
      break;
    }
  }

  // Try to remove 5 identical pairs
  int pairsRemoved = 0;
  for (int i = 0; i < available.length - 1 && pairsRemoved < 5; i++) {
    for (int j = i + 1; j < available.length && pairsRemoved < 5; j++) {
      if (available[i].number == available[j].number &&
          available[i].color == available[j].color &&
          !available[i].isOkey &&
          !available[j].isOkey) {
        final hi = j, lo = i;
        available.removeAt(hi);
        available.removeAt(lo);
        pairsRemoved++;
        break;
      }
    }
  }

  return available.length;
}

// ─── Okey helpers ────────────────────────────────────────────────────────────

/// Gösterge + 1 → Okey-Karte
Tile makeOkeyTile(Tile gosterge) =>
    Tile(gosterge.color, gosterge.number == 13 ? 1 : gosterge.number + 1, true);

/// Sahte Okey (Stern) — gleiche Position wie Okey
Tile makeFalseOkey(Tile gosterge) => makeOkeyTile(gosterge);

// ─── SYSTEM A: Runden-Strafpunkte ───────────────────────────────────────────

/// Berechnet die Strafpunkte eines VERLIERERS für eine Runde.
///
/// Die Multiplikatoren (Joker ×2, Çifte ×2) kommen vom GEWINNER,
/// nicht von jedem Spieler individually.
///
/// 1. Kein Foto → 100 (Anti-Schummel-Regel)
/// 2. basisPunkte × Tischfarbe
/// 3. × Joker-Finish (wenn Gewinner Okey abgelegt hat)
/// 4. × Çifte      (wenn Gewinner Çifte hatte)
int berechneStrafpunkte({
  required int basisPunkte,
  required TileColor tableColor,
  WinType winType = WinType.normal,
  bool hasProvidedPhoto = true,
}) {
  // 1. Anti-Schummel-Regel
  if (!hasProvidedPhoto) return noPhotoPenalty;

  // 2. Grundwert
  int factor = tableColorFactor(tableColor);

  // 3. Gewinner-Multiplikatoren
  switch (winType) {
    case WinType.okey:
    case WinType.cifte:
      factor *= 2;
      break;
    case WinType.okeyCifte:
      factor *= 4; // ×2 (joker) × ×2 (cifte)
      break;
    case WinType.normal:
      break;
  }

  return basisPunkte * factor;
}

/// Live-Faktor für die UI-Anzeige während der Runde.
/// Zeigt den aktuellen Multiplikator basierend auf Tischfarbe
/// und Gewinner-Status.
int liveFactor({
  required TileColor tableColor,
  WinType winType = WinType.normal,
}) {
  int f = tableColorFactor(tableColor);
  switch (winType) {
    case WinType.okey:       f *= 2; break;
    case WinType.cifte:      f *= 2; break;
    case WinType.okeyCifte:  f *= 4; break;
    case WinType.normal:      break;
  }
  return f;
}

// ─── SYSTEM B: Gösterge-Bonus / -Malus ─────────────────────────────────────

/// Gösterge-Zeigen: Belohnung = Farbwert × 10.
///
/// Der Gösterge kann ausschließlich DIREKT nach dem Austeilen
/// vorgezeigt werden (bevor der Halter seinen ersten Zug macht).
/// Danach verfällt das Recht für diese Runde.
///
/// Variante A (Straf-Variante): Halter 0, andere bekommen -(Farbwert × 10).
/// Variante B (Belohnungs-Variante): Halter bekommt -(Farbwert × 10).
/// Endabrechnng: Nach 11 Runden alle Strafpunkte (System A) minus
/// alle Gösterge-Minuspunkte (System B).
int berechneGostermeStrafe(TileColor tableColor) {
  return tableColorFactor(tableColor) * 10; // -20/-30/-40/-50
}

/// Gösterge-Belohnung (Halter-Variante).
/// Multiplikator × 10 als Langzeit-Konto.
int berechneGostermeBelohnung(TileColor tableColor) {
  return tableColorFactor(tableColor) * 10; // -20/-30/-40/-50 (Minuspunkte = gut)
}

int berechneGostermeStrafeHalter(TileColor tableColor) {
  return -berechneGostermeBelohnung(tableColor);
}

// ─── Çifte helpers ──────────────────────────────────────────────────────────

/// Wie viele Paare werden für Çifte benötigt?
int cifteRequiredPairs({bool isCifte = false}) => isCifte ? 5 : 7;

/// Wie viele Extra-Steine über 10 Paare hinaus?
int cifteExtraTiles({bool isCifte = false}) => isCifte ? 4 : 0;
