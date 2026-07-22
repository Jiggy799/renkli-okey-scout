// ─────────────────────────────────────────────────────────────────────────────
// OkeyScout — Game Engine
// Alle Regeln: okeyRules.ts (zentral, konfigurierbar)
// ─────────────────────────────────────────────────────────────────────────────

import {
  GÖSTERGE_FARBWERT,
  jokerNummer,
  SERIEN_WRAP_ALLOWED,
  SERIEN_1_STOP,
  GRUPPE_MIN_SIZE,
  CIFTE_MIN_PAIRS,
  CIFTE_REST_STONES,
  CIFTE_ALL_PAIRS,
  FOTO_STRAFE_PUNKTE,
  berechneVerliererStrafe,
  göstergeBonus,
  siegerMult,
  GÖSTERGE_LABELS,
  berechneVerliererStrafe as loserBaseMultiplier,
  göstergeBonus as göstergeZähle,
  type GöstergeColor,
  type SiegerTyp,
} from './okeyRules';

export type { GöstergeColor, SiegerTyp };
export { göstergeBonus, siegerMult, loserBaseMultiplier };

// ── Typen ────────────────────────────────────────────────────────────────────

export type TileColor = 'YELLOW' | 'BLUE' | 'RED' | 'BLACK';

export interface Tile {
  color:      TileColor;
  number:     number;
  isOkey?:    boolean;
  isFalseOkey?: boolean; // Sahte Okey (falscher Joker)
}

export interface Gösterge {
  color: GöstergeColor;
  number: number;
}

export interface HandValidation {
  valid:        boolean;
  reason?:      string;
  schrott:      Tile[];
  schrottSumme: number;
  serien:       Tile[][];
  gruppen:      Tile[][];
  paare:        Tile[][];
  isCifte:      boolean;
}

// ── Joker-Erkennung ─────────────────────────────────────────────────────────

export function istJoker(tile: Tile, gösterge: Gösterge): boolean {
  const jokerNr = jokerNummer(gösterge.number);
  return tile.color === gösterge.color && tile.number === jokerNr;
}

export function istSahteOkey(tile: Tile): boolean {
  return tile.isFalseOkey === true || tile.number === 0;
}

export function istOkey(tile: Tile, gösterge: Gösterge): boolean {
  return istJoker(tile, gösterge) || istSahteOkey(tile);
}

export function göstergeToOkey(gösterge: Gösterge): Tile {
  return { color: gösterge.color, number: jokerNummer(gösterge.number) };
}

// ── Farben & Labels ─────────────────────────────────────────────────────────

export const TILE_COLORS: TileColor[] = ['YELLOW', 'BLUE', 'RED', 'BLACK'];

export const TILE_COLOR_HEX: Record<TileColor, string> = {
  YELLOW: '#FFD700',
  BLUE:   '#1E90FF',
  RED:    '#E74C3C',
  BLACK:  '#1a1a1a',
};

export const TILE_COLOR_NAME: Record<TileColor, string> = {
  YELLOW: 'Gelb',
  BLUE:   'Blau',
  RED:    'Rot',
  BLACK:  'Schwarz',
};

export function steinLabel(tile: Tile): string {
  return `${TILE_COLOR_NAME[tile.color]} ${tile.number}`;
}

export function göstergeLabel(gösterge: Gösterge): string {
  const info = GÖSTERGE_LABELS[gösterge.color];
  return `${info.name} ${gösterge.number}`;
}

// ── Serien-Validierung ──────────────────────────────────────────────────────
// Joker (Echter Okey oder Sahte Okey) füllt GENAU ONE missing position in a serie.
// Wrap 13→1 ist erlaubt (12-13-1), aber 13-1-2 ist verboten.
export function istGueltigeSerie(tiles: Tile[], gösterge: Gösterge): boolean {
  if (tiles.length < 3) return false;

  // Zähle Jokers
  const jokerCount = tiles.filter(t => istJoker(t, gösterge) || istSahteOkey(t)).length;
  // Nicht-Joker
  const echte = tiles.filter(t => !istJoker(t, gösterge) && !istSahteOkey(t));

  if (echte.length === 0) return true; // Nur Jokers = gültig
  if (echte.length < 3 && jokerCount === 0) return false;
  if (echte.length + jokerCount < 3) return false;

  // Prüfe: alle gleiche Farbe
  const farbe = echte[0].color;
  if (!echte.every(t => t.color === farbe)) return false;

  // Sortiere (mit Wrap: 13 kommt vor 1)
  const sorted = [...echte].sort((a, b) => {
    if (a.number === 13) return -1;
    if (b.number === 13) return 1;
    if (a.number === 1) return 1;
    if (b.number === 1) return -1;
    return a.number - b.number;
  });

  // Prüfe Wrap: sorted[0]=12/13, sorted[sorted.length-1]=1 ?
  // Korrekter Wrap: [12,13,1] oder [13,1]
  // Wenn 13 UND 1 beide vorkommen: 13 muss an Index 0 ODER 1 sein
  // Bei sorted [1,...,13] → [1,...,12,13] → pairs: (1,2)...(12,13)
  // Bei sorted [12,13,1] → pairs: (12,13), (13,1) → 13→1 ist OK aber 13→1→?? muss geprüft werden

  // Extrahiere die Zahlen
  const zahlen = sorted.map(t => t.number);
  const hasOne = zahlen.includes(1);
  const hasThirteen = zahlen.includes(13);

  // Prüfe 13-1-2 verboten: Wenn 13 UND 1 und 2 existieren → ungültig
  if (hasOne && hasThirteen && zahlen.includes(2)) {
    // Prüfe ob 13 vor 1 kommt (falsche Reihenfolge = 13-1-2 ist impliziert)
    const idx1 = zahlen.indexOf(1);
    const idx13 = zahlen.indexOf(13);
    const idx2 = zahlen.indexOf(2);
    // Ist 2 zwischen 13 und 1? → nur möglich wenn [13, 2, ..., 1] oder [1, ..., 13, 2]
    // Vereinfacht: wenn die sortierte Reihenfolge 13→1 ist UND 2 existiert → verboten
    if (idx13 < idx1 && idx2 > idx13) return false;
  }

  // Prüfe Wrap-Fall: [12,13,1] oder [13,1]
  // sorted = [12, 13, 1] → pairs: (12,13)✓, (13,1)✓ mit wrap
  // sorted = [13, 1] → pairs: (13,1)✓
  // sorted = [11, 12, 13, 1] → pairs: (11,12)✓, (12,13)✓, (13,1)✓ mit wrap

  // Baue "virtual sorted" mit wrap-Position für 1: 1 bekommt position 14
  // Dann: 13→1 = consecutive (13→14 in virtual)
  const virtualZahlen = zahlen.map(n => n === 1 ? 14 : n);
  virtualZahlen.sort((a, b) => a - b);

  let jokerBudget = jokerCount;

  for (let i = 0; i < virtualZahlen.length - 1; i++) {
    const curr = virtualZahlen[i];
    const next = virtualZahlen[i + 1];
    const gap = next - curr;

    if (gap === 1) continue; // consecutive ✓
    if (gap === 0) return false; // duplikat

    // gap > 1:braucht Joker(s)
    if (gap - 1 <= jokerBudget) {
      jokerBudget -= (gap - 1);
      continue;
    }
    return false; // gap zu groß für Joker-Budget
  }

  return true;
}

// ── Gruppen-Validierung ─────────────────────────────────────────────────────

export function istGueltigeGruppe(tiles: Tile[], gösterge: Gösterge): boolean {
  if (tiles.length < GRUPPE_MIN_SIZE) return false;
  const echte = tiles.filter(t => !istJoker(t, gösterge) && !istSahteOkey(t));
  if (echte.length < GRUPPE_MIN_SIZE) return false;
  const ersteZahl = echte[0].number;
  if (!echte.every(t => t.number === ersteZahl)) return false;
  const farben = echte.map(t => t.color);
  const uniqueFarben = [...new Set(farben)];
  if (uniqueFarben.length !== farben.length) return false;
  return true;
}

// ── Paar / Çifte ────────────────────────────────────────────────────────────

function istGueltigesPaar(tiles: Tile[]): boolean {
  if (tiles.length !== 2) return false;
  return tiles[0].color === tiles[1].color && tiles[0].number === tiles[1].number;
}

/** Prüft ob alle 14 Steine genau 7 gültige Doppel-Paare sind (Variante 1: 7 Paare = Çifte) */
function ist7DoppelPaare(tiles: Tile[], gösterge: Gösterge): boolean {
  if (tiles.length !== 14) return false;

  const remaining = [...tiles];
  const pairCount = Math.floor(remaining.length / 2);
  let pairs = 0;

  for (let i = 0; i < remaining.length - 1; i++) {
    for (let j = i + 1; j < remaining.length; j++) {
      const paar = [remaining[i], remaining[j]];
      if (istGueltigesPaar(paar)) {
        pairs++;
        remaining.splice(j, 1);
        remaining.splice(i, 1);
        break;
      }
    }
  }

  return pairs === 7 && remaining.length === 0;
}

// ── Blatt-Validierung ───────────────────────────────────────────────────────

export function validiereBlatt(tiles: Tile[], gösterge: Gösterge): HandValidation {
  if (tiles.length !== 14) {
    return {
      valid: false,
      reason: 'Kein vollständiges Blatt (14 Steine)',
      schrott: tiles,
      schrottSumme: summe(tiles),
      serien: [], gruppen: [], paare: [], isCifte: false,
    };
  }

  // Variante 1: Alle 14 Steine = 7 Doppel-Paare → gültig, 0 Schrott
  if (tiles.length === 14 && ist7DoppelPaare(tiles, gösterge)) {
    const paare: Tile[][] = [];
    const remaining = [...tiles];
    for (let i = 0; i < remaining.length - 1; i++) {
      for (let j = i + 1; j < remaining.length; j++) {
        const paar = [remaining[i], remaining[j]];
        if (istGueltigesPaar(paar)) {
          paare.push([...paar]);
          remaining.splice(j, 1);
          remaining.splice(i, 1);
          break;
        }
      }
    }
    return {
      valid: true, schrott: [], schrottSumme: 0,
      serien: [], gruppen: [], paare, isCifte: true,
    };
  }

  const ergebnis = backtrackPartition([...tiles], gösterge, 0);

  if (ergebnis) {
    const schrott = findeSchrott(tiles, ergebnis);
    return {
      valid:       true,
      schrott,
      schrottSumme: summe(schrott),
      serien:      ergebnis.serien,
      gruppen:     ergebnis.gruppen,
      paare:       ergebnis.paare,
      isCifte:     ergebnis.paare.length >= CIFTE_MIN_PAIRS || ist7DoppelPaare(tiles, gösterge),
    };
  }

  return {
    valid: false,
    reason: 'Kein gültiges Blatt',
    schrott: [...tiles],
    schrottSumme: summe(tiles),
    serien: [], gruppen: [], paare: [], isCifte: false,
  };
}

interface PartitionResult {
  serien:  Tile[][];
  gruppen: Tile[][];
  paare:   Tile[][];
}

function backtrackPartition(
  remaining: Tile[],
  gösterge:  Gösterge,
  depth:     number,
): PartitionResult | null {
  if (remaining.length === 0) return { serien: [], gruppen: [], paare: [] };
  if (depth > 50) return null;

  for (let len = 3; len <= Math.min(remaining.length, 13); len++) {
    for (const combo of allCombinations(remaining, len)) {
      if (istGueltigeSerie(combo, gösterge)) {
        const rest = removeAll(remaining, combo);
        const sub  = backtrackPartition(rest, gösterge, depth + 1);
        if (sub) return { serien: [[...combo], ...sub.serien], gruppen: sub.gruppen, paare: sub.paare };
      }
    }
  }

  for (let len = GRUPPE_MIN_SIZE; len <= Math.min(remaining.length, 4); len++) {
    for (const combo of allCombinations(remaining, len)) {
      if (istGueltigeGruppe(combo, gösterge)) {
        const rest = removeAll(remaining, combo);
        const sub  = backtrackPartition(rest, gösterge, depth + 1);
        if (sub) return { serien: sub.serien, gruppen: [[...combo], ...sub.gruppen], paare: sub.paare };
      }
    }
  }

  for (let i = 0; i < remaining.length - 1; i++) {
    for (let j = i + 1; j < remaining.length; j++) {
      const paar = [remaining[i], remaining[j]];
      if (istGueltigesPaar(paar)) {
        const rest = remaining.filter((_, idx) => idx !== i && idx !== j);
        const sub  = backtrackPartition(rest, gösterge, depth + 1);
        if (sub) return { serien: sub.serien, gruppen: sub.gruppen, paare: [[...paar], ...sub.paare] };
      }
    }
  }

  return null;
}

function allCombinations(arr: Tile[], k: number): Tile[][] {
  if (k === arr.length) return [[...arr]];
  if (k > arr.length) return [];
  const results: Tile[][] = [];
  function go(idx: number, current: Tile[]) {
    if (current.length === k) { results.push([...current]); return; }
    if (idx >= arr.length) return;
    go(idx + 1, current);
    go(idx + 1, [...current, arr[idx]]);
  }
  go(0, []);
  return results;
}

function removeAll(arr: Tile[], toRemove: Tile[]): Tile[] {
  const removeKeys = new Set(toRemove.map(t => `${t.color}-${t.number}`));
  return arr.filter(t => {
    const k = `${t.color}-${t.number}`;
    if (removeKeys.has(k)) { removeKeys.delete(k); return false; }
    return true;
  });
}

function findeSchrott(allTiles: Tile[], part: PartitionResult): Tile[] {
  const used = new Set<string>();
  const key  = (t: Tile) => `${t.color}-${t.number}`;
  for (const s of part.serien)  for (const t of s) used.add(key(t));
  for (const g of part.gruppen) for (const t of g) used.add(key(t));
  for (const p of part.paare)   for (const t of p) used.add(key(t));
  return allTiles.filter(t => !used.has(key(t)));
}

function summe(tiles: Tile[]): number {
  return tiles.reduce((acc, t) => acc + (t.number || 0), 0);
}

// ── Scoring ─────────────────────────────────────────────────────────────────

export function berechneVerliererPunkte(
  hand:      HandValidation,
  gösterge:  Gösterge,
  siegerTyp: SiegerTyp,
): number {
  return berechneVerliererStrafe(hand.schrottSumme, gösterge.color, siegerTyp);
}

export type WinType = SiegerTyp;

export function verifyHandAndCalculateScore(
  hand:                    Tile[],
  gösterge:                Gösterge,
  _isFalseFinish:          boolean,
  _winnerDiscardedOkey:    boolean,
): { valid: boolean; score: number; reason?: string; winType?: SiegerTyp } {
  const result = validiereBlatt(hand, gösterge);
  if (!result.valid) return { valid: false, score: 0, reason: result.reason };
  const score = göstergeBonus(gösterge.color);
  return { valid: true, score, winType: result.isCifte ? 'CIFTE' : 'NORMAL' };
}

// ── Test-Hilfen ──────────────────────────────────────────────────────────────

export function createTile(color: TileColor, number: number): Tile {
  return { color, number };
}

export function generateAllTiles(): Tile[] {
  const tiles: Tile[] = [];
  for (const color of TILE_COLORS) {
    for (let n = 1; n <= 13; n++) {
      tiles.push(createTile(color, n));
      tiles.push(createTile(color, n));
    }
  }
  tiles.push({ color: 'RED',    number: 0, isOkey: false } as Tile);
  tiles.push({ color: 'YELLOW', number: 0, isOkey: false } as Tile);
  return tiles;
}

export function generateRandomHand(): Tile[] {
  const all = generateAllTiles();
  return [...all].sort(() => Math.random() - 0.5).slice(0, 14);
}
