// ─────────────────────────────────────────────────────────────────────────────
// OkeyScout — Regelwerk (konfigurierbar)
// Alle Okey-Regeln sind hier zentral definiert.
// Änderungen hier wirken sich auf die gesamte App aus.
// ─────────────────────────────────────────────────────────────────────────────

// ── Grundwerte der Farben ────────────────────────────────────────────────────
// Der Farbwert des Gösterge bestimmt die Multiplikatoren.
// Gelb=2, Blau=3, Rot=4, Schwarz=5
export const GÖSTERGE_FARBWERT: Record<GöstergeColor, number> = {
  YELLOW: 2,
  BLUE:   3,
  RED:    4,
  BLACK:  5,
};

export type GöstergeColor = 'YELLOW' | 'BLUE' | 'RED' | 'BLACK';

// ── Joker (Okey) ─────────────────────────────────────────────────────────────
// Der Joker ist immer der Stein genau EINE Zahl über dem Gösterge, gleiche Farbe.
// Beispiel: Gösterge Rot 5 → Joker ist Rot 6.
// Ist der Gösterge eine 13, ist die 1 derselben Farbe der Joker.
export function jokerNummer(göstergeNummer: number): number {
  return göstergeNummer === 13 ? 1 : göstergeNummer + 1;
}

// ── 13-zu-1-Regel ───────────────────────────────────────────────────────────
// 12, 13, 1 ist ERLAUBT (die 1 ist der absolute Stopp).
// 13, 1, 2 ist VERBOTEN.
export const SERIEN_MIN_LENGTH   = 3;
export const SERIEN_MAX_LENGTH   = 13; // theoretisch 13 (1..13), praktisch selten > 5
export const SERIEN_WRAP_ALLOWED = true; // 12→13→1 ist erlaubt
export const SERIEN_1_STOP       = true; // 13→1→2 ist verboten

// ── Gruppen ─────────────────────────────────────────────────────────────────
// Mindestens 3 Steine mit derselben Zahl, unterschiedlichen Farben.
export const GRUPPE_MIN_SIZE = 3;
export const GRUPPE_MAX_SIZE = 4; // max 4 Farben

// ── Çifte (Paare) ────────────────────────────────────────────────────────────
// Variante 1: 7 Doppel-Paare (alle 14 Steine = Paare) → 0 Schrott
// Variante 2: Mindestens 5 exakte Paare + eine einfarbige 4er-Reihe
export const CIFTE_MIN_PAIRS    = 5;
export const CIFTE_REST_STONES   = 4; // einfarbige Reihe (Variante 2)
export const CIFTE_ALL_PAIRS    = 7; // 7 Paare = alle 14 Steine (Variante 1)

// ── Foto-Pflicht ────────────────────────────────────────────────────────────
// Wer am Rundenende KEIN Foto abliefert: +100 Strafpunkte.
export const FOTO_STRAFE_PUNKTE = 100;

// ── System A: Runden-Strafpunkte ───────────────────────────────────────────
// Verlierer: Summe der "Schrott-Steine" (nicht in gültigen Kombinationen)
// × Gösterge-Farbwert × Sieger-Multiplikator
//
// Sieger-Multiplikator:
//   Normal:      ×1
//   Okey atmak:  ×2
//   Çifte:       ×2
//   Okey+Çifte:  ×4
export function berechneVerliererStrafe(
  schrottSumme: number,        // Augenzahlen der unverwendeten Steine
  göstergeColor: GöstergeColor,
  siegerTyp: SiegerTyp,
): number {
  const farbwert   = GÖSTERGE_FARBWERT[göstergeColor];
  const multiplikator = siegerMult(siegerTyp);
  return schrottSumme * farbwert * multiplikator;
}

export type SiegerTyp = 'NORMAL' | 'OKEY' | 'CIFTE' | 'OKEY_CIFTE';

export function siegerMult(typ: SiegerTyp): number {
  switch (typ) {
    case 'NORMAL':     return 1;
    case 'OKEY':
    case 'CIFTE':      return 2;
    case 'OKEY_CIFTE': return 4;
  }
}

// ── System B: Gösterge-Bonuskonto ──────────────────────────────────────────
// Zeigt ein Spieler beim Austeilen den Gösterge VOR → Bonus-Minuspunkte.
// Bonus = Farbwert × 10
// Endabrechnung nach 10 Runden: Bonus wird von Gesamt-Strafpunkten abgezogen.
export function göstergeBonus(göstergeColor: GöstergeColor): number {
  return GÖSTERGE_FARBWERT[göstergeColor] * 10;
}

export const RUNDEN_PRO_PARTIE = 10; // Partie-Länge

// ── Zusammenfassung aller Farbwerte (für die UI) ────────────────────────────
export const GÖSTERGE_LABELS: Record<GöstergeColor, { name: string; wert: number; bonus: number }> = {
  YELLOW: { name: 'Gelb',  wert: 2, bonus: 20 },
  BLUE:   { name: 'Blau',  wert: 3, bonus: 30 },
  RED:    { name: 'Rot',   wert: 4, bonus: 40 },
  BLACK:  { name: 'Schwarz', wert: 5, bonus: 50 },
};
