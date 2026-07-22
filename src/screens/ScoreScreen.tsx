// ─────────────────────────────────────────────────────────────────────────────
// ScoreScreen — Zeigt das Ergebnis einer Runde mit beiden Bewertungssystemen
// System A: Runden-Strafpunkte (Verlierer)
// System B: Gösterge-Bonuskonto (über 10 Runden)
// Foto-Pflicht: Wer kein Foto macht → +100 Strafpunkte
// ─────────────────────────────────────────────────────────────────────────────

import React, { useState } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, ScrollView,
} from 'react-native';
import type { GöstergeTile } from '../services/supabase';
import type { Gösterge, Tile, HandValidation, SiegerTyp } from '../utils/okeyEngine';
import {
  validiereBlatt,
  berechneVerliererPunkte,
  göstergeLabel,
  TILE_COLOR_HEX,
  TILE_COLOR_NAME,
} from '../utils/okeyEngine';
import {
  göstergeBonus,
  GÖSTERGE_LABELS,
  berechneVerliererStrafe,
  FOTO_STRAFE_PUNKTE,
  type GöstergeColor,
} from '../utils/okeyRules';

type Props = {
  /** Optional: Tisch-ID für Multiplayer (nicht erforderlich für Einzelspieler) */
  tableId?: string;
  /** Der gescannte gösterge Stein */
  gösterge: GöstergeTile;
  /** Alle 14 Steine des Spielers */
  hand: Tile[];
  /** Art des Gewinners (NORMAL, OKEY, CIFTE, OKEY_CIFTE) */
  winType: SiegerTyp;
  /** Hat der Sieger Okey abgelegt? */
  winnerDiscardedOkey: boolean;
  /** Foto wurde gemacht ja/nein */
  fotoGemacht: boolean;
  onBack: () => void;
  onScanAgain: () => void;
};

const GÖSTERGE_COLOR_MAP: Record<string, GöstergeColor> = {
  YELLOW: 'YELLOW', BLUE: 'BLUE', RED: 'RED', BLACK: 'BLACK',
};

export default function ScoreScreen({
  gösterge, hand, winType, winnerDiscardedOkey, fotoGemacht, onBack, onScanAgain,
}: Props) {
  const göstergeObj: Gösterge = {
    color: GÖSTERGE_COLOR_MAP[gösterge.color] ?? 'YELLOW',
    number: gösterge.number,
  };

  const validation: HandValidation = validiereBlatt(hand, göstergeObj);
  const info = GÖSTERGE_LABELS[göstergeObj.color];

  // System A: Verlierer-Strafe
  const verliererStrafe = validation.valid
    ? berechneVerliererPunkte(validation, göstergeObj, winType)
    : 0;

  // System B: Gösterge-Vorzeige-Bonus
  const göstergeBonusPunkte = göstergeBonus(göstergeObj.color);

  // Foto-Strafe
  const fotoStrafe = fotoGemacht ? 0 : FOTO_STRAFE_PUNKTE;

  // Gewinner bekommt die Zähne gutgeschrieben
  const gewinnerPunkte = validation.valid ? info.wert : 0;

  // Multiplikator anzeige
  const siegerMult = winType === 'OKEY_CIFTE' ? 4 : winType === 'OKEY' || winType === 'CIFTE' ? 2 : 1;

  // Simuliere 3 Verlierer mit Platzhalter-Augenzahlen
  const platzhalterVerlierer = [
    { label: 'Spieler 2', augenSumme: 42 },
    { label: 'Spieler 3', augenSumme: 67 },
    { label: 'Spieler 4', augenSumme: 25 },
  ];

  return (
    <View style={S.container}>
      {/* Header */}
      <View style={S.header}>
        <TouchableOpacity onPress={onBack}>
          <Text style={S.backTxt}>←</Text>
        </TouchableOpacity>
        <Text style={S.headerTitle}>Runde Ergebnis</Text>
        <TouchableOpacity onPress={onScanAgain}>
          <Text style={S.rescanTxt}>↻</Text>
        </TouchableOpacity>
      </View>

      <ScrollView style={S.body} contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Gösterge Anzeige */}
        <GöstergeCard gösterge={göstergeObj} />

        {/* Gewinner-Banner */}
        {validation.valid ? (
          <WinBanner gewinnerPunkte={gewinnerPunkte} winType={winType} />
        ) : (
          <InvalidBanner reason={validation.reason ?? 'Ungültiges Blatt'} />
        )}

        {/* Blatt-Analyse */}
        <BlattAnalyse validation={validation} />

        {/* ── SYSTEM A: Runden-Strafpunkte ── */}
        <SystemACard
          gösterge={göstergeObj}
          siegerTyp={winType}
          siegerMult={siegerMult}
          verliererStrafe={verliererStrafe}
          platzhalterVerlierer={platzhalterVerlierer}
        />

        {/* ── SYSTEM B: Gösterge-Bonus ── */}
        <SystemBCard göstergeBonusPunkte={göstergeBonusPunkte} gösterge={göstergeObj} />

        {/* ── Foto-Pflicht ── */}
        <FotoPflichtCard fotoGemacht={fotoGemacht} />

        {/* Regel-Hinweis */}
        <View style={S.regelHinweis}>
          <Text style={S.regelHinweisTxt}>
            💡 System A: Verlierer zahlen Schrott × {info.wert} × {siegerMult} = {verliererStrafe} Punkte.{'\n'}
            💡 System B: Gösterge-Vorzeige-Minuspunkte werden am Ende abgezogen.{'\n'}
            💡 Kein Foto = +{FOTO_STRAFE_PUNKTE} Strafpunkte.
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}

// ── Sub-Komponenten ───────────────────────────────────────────────────────────

function GöstergeCard({ gösterge }: { gösterge: Gösterge }) {
  const info = GÖSTERGE_LABELS[gösterge.color];
  const hex  = TILE_COLOR_HEX[gösterge.color] ?? '#888';

  return (
    <View style={S.göstergeCard}>
      <Text style={S.göstergeLabel}>Gösterge</Text>
      <View style={[S.göstergeStein, { backgroundColor: hex }]}>
        <Text style={S.göstergeNummer}>{gösterge.number}</Text>
      </View>
      <Text style={S.göstergeInfo}>
        {info.name} · Wert {info.wert} · Bonus {info.bonus}
      </Text>
    </View>
  );
}

function WinBanner({ gewinnerPunkte, winType }: { gewinnerPunkte: number; winType: SiegerTyp }) {
  const labels: Record<SiegerTyp, string> = {
    NORMAL: 'GEWONNEN!',
    OKEY:   '🎯 OKEY!',
    CIFTE:  '👑 ÇIFTE!',
    OKEY_CIFTE: '🎯👑 OKEY + ÇIFTE!',
  };

  return (
    <View style={S.banner}>
      <Text style={S.bannerTitle}>{labels[winType]}</Text>
      <Text style={S.bannerScore}>+{gewinnerPunkte} Punkte gutgeschrieben</Text>
    </View>
  );
}

function InvalidBanner({ reason }: { reason: string }) {
  return (
    <View style={S.invalidBanner}>
      <Text style={S.invalidBannerTxt}>❌ {reason}</Text>
    </View>
  );
}

function BlattAnalyse({ validation }: { validation: HandValidation }) {
  const hex = '#e94560';
  const isCifte7Paare = validation.paare.length === 7;
  return (
    <View style={S.card}>
      <Text style={S.cardTitle}>Blatt-Analyse</Text>
      <Text style={S.cardRow}>
        Gültig: <Text style={{ color: validation.valid ? '#2ecc71' : hex }}>{validation.valid ? '✓' : '✗'}</Text>
      </Text>
      <Text style={S.cardRow}>Serien: {validation.serien.length}</Text>
      <Text style={S.cardRow}>Gruppen: {validation.gruppen.length}</Text>
      {validation.paare.length > 0 && (
        <Text style={S.cardRow}>
          Paare (Çifte): {validation.paare.length}
          {isCifte7Paare ? ' — Variante: 7 Doppel-Paare ✓' : ' — Variante: 5 Paare + 4er-Reihe'}
        </Text>
      )}
      <Text style={S.cardRow}>
        Schrott: <Text style={{ color: hex }}>{validation.schrott.length} Steine</Text>
        {' '}(Summe: {validation.schrottSumme})
      </Text>
    </View>
  );
}

function SystemACard({
  gösterge, siegerTyp, siegerMult, verliererStrafe, platzhalterVerlierer,
}: {
  gösterge: Gösterge;
  siegerTyp: SiegerTyp;
  siegerMult: number;
  verliererStrafe: number;
  platzhalterVerlierer: { label: string; augenSumme: number }[];
}) {
  const info = GÖSTERGE_LABELS[gösterge.color];

  return (
    <View style={S.card}>
      <Text style={[S.cardTitle, { color: '#e74c3c' }]}>⚠️ System A: Runden-Strafpunkte</Text>
      <Text style={S.cardRow}>
        Schrott-Summe × {info.wert} ({info.name}) × {siegerMult} ({siegerTyp})
      </Text>
      <Text style={S.cardRow}>
        = {verliererStrafe} Punkte pro Verlierer
      </Text>
      <View style={S.divider} />
      <Text style={S.cardRow}>Beispiel-Verlierer:</Text>
      {platzhalterVerlierer.map(p => (
        <View key={p.label} style={S.verliererRow}>
          <Text style={S.verliererLabel}>{p.label}</Text>
          <Text style={S.verliererWert}>
            {p.augenSumme} × {info.wert} × {siegerMult} = {p.augenSumme * info.wert * siegerMult}
          </Text>
        </View>
      ))}
    </View>
  );
}

function SystemBCard({ göstergeBonusPunkte, gösterge }: { göstergeBonusPunkte: number; gösterge: Gösterge }) {
  const info = GÖSTERGE_LABELS[gösterge.color];

  return (
    <View style={[S.card, { borderColor: '#f39c12', borderWidth: 1 }]}>
      <Text style={[S.cardTitle, { color: '#f39c12' }]}>🌟 System B: Gösterge-Bonus</Text>
      <Text style={S.cardRow}>
        Gösterge {info.name} {gösterge.number} vorgezeigt → <Text style={{ color: '#e74c3c' }}>
          -{göstergeBonusPunkte} Minuspunkte
        </Text>
      </Text>
      <Text style={S.cardRow}>
        Wird am Ende der 10 Runden von den Gesamtstrafpunkten abgezogen.
      </Text>
      <Text style={S.cardHint}>
        ↳ Negativ möglich! Beispiel: 90 Minuspunkte - 150 Strafpunkte = -60 (ins Minus!)
      </Text>
    </View>
  );
}

function FotoPflichtCard({ fotoGemacht }: { fotoGemacht: boolean }) {
  return (
    <View style={[S.card, { borderColor: fotoGemacht ? '#2ecc71' : '#e74c3c', borderWidth: 1 }]}>
      <Text style={[S.cardTitle, { color: fotoGemacht ? '#2ecc71' : '#e74c3c' }]}>
        📸 Foto-Pflicht
      </Text>
      {fotoGemacht ? (
        <Text style={{ color: '#2ecc71' }}>✓ Foto wurde gemacht — keine Strafe</Text>
      ) : (
        <Text style={{ color: '#e74c3c' }}>
          ✗ Kein Foto → +{FOTO_STRAFE_PUNKTE} Strafpunkte!
        </Text>
      )}
    </View>
  );
}

// ── Styles ───────────────────────────────────────────────────────────────────

const S = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#0f0f1a' },
  header:     { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 50, paddingHorizontal: 16, paddingBottom: 12 },
  backTxt:    { fontSize: 28, color: '#fff' },
  headerTitle:{ fontSize: 18, fontWeight: '700', color: '#fff' },
  rescanTxt:  { fontSize: 24, color: '#e94560' },
  body:       { flex: 1, paddingHorizontal: 16 },

  göstergeCard: { alignItems: 'center', marginBottom: 20, backgroundColor: 'rgba(255,255,255,0.05)', borderRadius: 16, padding: 20 },
  göstergeLabel:{ color: 'rgba(255,255,255,0.5)', fontSize: 13, marginBottom: 10 },
  göstergeStein:{ width: 56, height: 80, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginBottom: 10, borderWidth: 2, borderColor: 'rgba(255,255,255,0.2)' },
  göstergeNummer:{ fontSize: 28, fontWeight: '900', color: '#fff' },
  göstergeInfo: { color: 'rgba(255,255,255,0.6)', fontSize: 13 },

  banner:      { backgroundColor: '#1a5f2a', borderRadius: 16, padding: 20, alignItems: 'center', marginBottom: 16 },
  bannerTitle: { fontSize: 22, fontWeight: '900', color: '#fff', marginBottom: 6 },
  bannerScore: { fontSize: 16, color: 'rgba(255,255,255,0.8)' },

  invalidBanner:{ backgroundColor: '#5f1a1a', borderRadius: 16, padding: 20, alignItems: 'center', marginBottom: 16 },
  invalidBannerTxt:{ color: '#e74c3c', fontSize: 16, fontWeight: '700' },

  card:       { backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 16, marginBottom: 16 },
  cardTitle:  { color: '#fff', fontSize: 15, fontWeight: '700', marginBottom: 10 },
  cardRow:    { color: 'rgba(255,255,255,0.7)', fontSize: 13, marginBottom: 4 },
  cardHint:   { color: 'rgba(255,255,255,0.4)', fontSize: 12, marginTop: 6, fontStyle: 'italic' },
  divider:    { height: 1, backgroundColor: 'rgba(255,255,255,0.1)', marginVertical: 10 },

  verliererRow:{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  verliererLabel:{ color: 'rgba(255,255,255,0.7)', fontSize: 13 },
  verliererWert:{ color: '#e74c3c', fontSize: 13, fontWeight: '600' },

  regelHinweis:{ backgroundColor: 'rgba(255,255,255,0.04)', borderRadius: 12, padding: 14, marginBottom: 20 },
  regelHinweisTxt:{ color: 'rgba(255,255,255,0.45)', fontSize: 12, lineHeight: 20 },
});
