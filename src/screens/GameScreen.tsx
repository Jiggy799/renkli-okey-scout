/**
 * OkeyScout — Game Screen
 * src/screens/GameScreen.tsx
 *
 * Full in-game screen:
 *   - Shows gösterge and derived Okey tile
 *   - Displays player's 15-tile rack (loaded from Supabase or placeholder)
 *   - Draw / Discard / Submit actions
 *   - Win-condition flags: winnerDiscardedOkey (Okey atmak), winnerPairedOnly (Çifte bitmek)
 *   - Navigates to ScoreScreen on hand submission
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity, ScrollView,
  ActivityIndicator, Alert,
} from 'react-native';
import type { GöstergeTile } from '../services/supabase';
import type { Tile, TileColor, Gösterge } from '../utils/okeyEngine';
import { göstergeToOkey, istOkey } from '../utils/okeyEngine';
import { getSupabase } from '../services/supabase';

type Props = {
  tableId:     string;
  gösterge:   GöstergeTile;
  userId:     string;
  onFinishHand: (hand: Tile[], winnerDiscardedOkey: boolean, winnerPairedOnly: boolean) => void;
  onLeaveTable: () => void;
};

// ── Tile colors for UI ──────────────────────────────────────────────────────
const TILE_COLORS: Record<string, string> = {
  RED:    '#c0392b',
  BLACK:  '#1a1a1a',
  BLUE:   '#2980b9',
  YELLOW: '#f1c40f',
};

// ── Placeholder hand (when no Supabase hand record exists) ──────────────────
function buildPlaceholderHand(gösterge: GöstergeTile): Tile[] {
  // Generate a plausible-looking random hand for demo purposes
  const colors: TileColor[] = ['RED', 'BLACK', 'BLUE', 'YELLOW'];
  const hand: Tile[] = [];
  const used = new Set<string>();

  while (hand.length < 15) {
    const color = colors[Math.floor(Math.random() * colors.length)];
    const number = Math.floor(Math.random() * 13) + 1;
    const key = `${color}-${number}`;
    const count = hand.filter(t => t.color === color && t.number === number).length;
    if (count < 2 && !used.has(key)) {
      used.add(key);
      hand.push({ color, number });
    }
  }
  return hand;
}

// ── Single tile component ────────────────────────────────────────────────────
type TileViewProps = {
  tile: Tile;
  selected?: boolean;
  onPress?: () => void;
  gösterge: Gösterge;
  small?: boolean;
};

function TileView({ tile, selected, onPress, gösterge, small }: TileViewProps) {
  const isWild = istOkey(tile, gösterge);
  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={!onPress}
      style={[
        small ? S.tileSmall : S.tile,
        { backgroundColor: TILE_COLORS[tile.color] ?? '#888' },
        selected && S.tileSelected,
        isWild && S.tileOkey,
      ]}
    >
      <Text style={[small ? S.tileTxtSmall : S.tileTxt, isWild && S.tileTxtOkey]}>
        {isWild ? '★' : tile.number}
      </Text>
    </TouchableOpacity>
  );
}

// ── GameScreen ────────────────────────────────────────────────────────────────
export default function GameScreen({
  tableId, gösterge: göstergeTile, userId,
  onFinishHand, onLeaveTable,
}: Props) {
  const gösterge: Gösterge = { color: göstergeTile.color as TileColor, number: göstergeTile.number };
  const okeyTile = göstergeToOkey(gösterge);

  // ── Player's hand ────────────────────────────────────────────────────────
  const [hand,       setHand]       = useState<Tile[]>([]);
  const [loadingHand, setLoadingHand] = useState(true);

  // ── Game state ───────────────────────────────────────────────────────────
  const [selectedTileIndex, setSelectedTileIndex] = useState<number | null>(null);
  const [roundNumber, setRoundNumber] = useState(1);
  const [turnCount,  setTurnCount]   = useState(1);

  // ── Win-condition flags (Okey atmak / Çifte bitmek) ──────────────────────
  const [winnerDiscardedOkey, setWinnerDiscardedOkey] = useState(false);
  const [winnerPairedOnly,     setWinnerPairedOnly]     = useState(false);

  // ── Load hand from Supabase (or use placeholder) ────────────────────────
  useEffect(() => {
    async function loadHand() {
      // Try to load the player's current hand from round_hands table
      const { data, error } = await getSupabase()
        .from('round_hands')
        .select('tiles')
        .eq('table_id', tableId)
        .eq('player_id', userId)
        .eq('round_number', 1) // TODO: support multiple rounds
        .single();

      if (!error && data?.tiles && Array.isArray(data.tiles) && data.tiles.length === 15) {
        setHand(data.tiles as Tile[]);
      } else {
        // Use placeholder hand for demo / when no DB record exists yet
        setHand(buildPlaceholderHand(göstergeTile));
      }
      setLoadingHand(false);
    }
    loadHand();
  }, [tableId, userId, göstergeTile]);

  // ── Tile selection ───────────────────────────────────────────────────────
  const handleTilePress = useCallback((index: number) => {
    setSelectedTileIndex(prev => prev === index ? null : index);
  }, []);

  // ── Discard selected tile ────────────────────────────────────────────────
  const handleDiscard = useCallback(async () => {
    if (selectedTileIndex === null) {
      Alert.alert('Kein Stein ausgewählt', 'Wähle zuerst einen Stein zum Abwerfen.');
      return;
    }
    const discarded = hand[selectedTileIndex];
    const newHand = hand.filter((_, i) => i !== selectedTileIndex);

    // TODO: sync discarded tile to Supabase (discard_pile table)
    setHand(newHand);
    setSelectedTileIndex(null);
    setTurnCount(c => c + 1);

    // Check if the discarded tile was an Okey (Okey atmak)
    if (istOkey(discarded, gösterge)) {
      setWinnerDiscardedOkey(true);
    }
  }, [selectedTileIndex, hand, gösterge]);

  // ── Draw from pool (placeholder) ───────────────────────────────────────
  const handleDraw = useCallback(() => {
    if (hand.length >= 15) {
      Alert.alert('Hand voll', 'Du hast bereits 15 Steine. Bitte erst einen abwerfen.');
      return;
    }
    // TODO: draw real tile from pool (Supabase pool management)
    // For now, generate a random tile
    const colors: TileColor[] = ['RED', 'BLACK', 'BLUE', 'YELLOW'];
    const newTile: Tile = {
      color:  colors[Math.floor(Math.random() * colors.length)],
      number: Math.floor(Math.random() * 13) + 1,
    };
    setHand([...hand, newTile]);
  }, [hand]);

  // ── Submit hand for scoring ──────────────────────────────────────────────
  const handleSubmitHand = useCallback(() => {
    if (hand.length !== 15) {
      Alert.alert('Fehler', `Du brauchst genau 15 Steine (hast ${hand.length}).`);
      return;
    }
    onFinishHand(hand, winnerDiscardedOkey, winnerPairedOnly);
  }, [hand, winnerDiscardedOkey, winnerPairedOnly, onFinishHand]);

  // ── Leave table ──────────────────────────────────────────────────────────
  const handleLeave = useCallback(() => {
    Alert.alert('Tisch verlassen?', 'Du verlässt das laufende Spiel.', [
      { text: 'Abbrechen', style: 'cancel' },
      { text: 'Verlassen', style: 'destructive', onPress: onLeaveTable },
    ]);
  }, [onLeaveTable]);

  // ── Render ────────────────────────────────────────────────────────────────
  if (loadingHand) {
    return (
      <View style={S.centered}>
        <ActivityIndicator size="large" color="#e94560" />
        <Text style={S.loadingTxt}>Hand wird geladen…</Text>
      </View>
    );
  }

  return (
    <View style={S.container}>
      {/* Header */}
      <View style={S.header}>
        <TouchableOpacity onPress={handleLeave}>
          <Text style={S.backTxt}>←</Text>
        </TouchableOpacity>
        <Text style={S.headerTitle}>Tisch {tableId}</Text>
        <View style={S.turnBadge}>
          <Text style={S.turnTxt}>Runde {roundNumber}</Text>
        </View>
      </View>

      {/* Gösterge banner */}
      <View style={S.göstergeBanner}>
        <View style={S.göstergeGroup}>
          <Text style={S.göstergeLbl}>Gösterge</Text>
          <View style={[S.göstergeTile, { backgroundColor: TILE_COLORS[gösterge.color] }]}>
            <Text style={S.göstergeTileTxt}>{gösterge.number}</Text>
          </View>
        </View>
        <View style={S.okeyGroup}>
          <Text style={S.göstergeLbl}>Okey =</Text>
          <View style={[S.göstergeTile, S.okeyTile, { backgroundColor: TILE_COLORS[okeyTile.color] }]}>
            <Text style={S.göstergeTileTxt}>{okeyTile.number}</Text>
          </View>
          {istOkey({ color: gösterge.color, number: gösterge.number, isFalseOkey: false }, gösterge) && (
            <Text style={S.okeyHint}>★</Text>
          )}
        </View>
        <Text style={S.renkliTag}>
          {gösterge.color === 'RED' || gösterge.color === 'BLACK' ? 'RENKLİ ×2' : 'Standard ×1'}
        </Text>
      </View>

      {/* Win-condition flags */}
      <View style={S.flagsBanner}>
        <Text style={S.flagsLabel}>Sieg-Bedingungen:</Text>
        <View style={S.flagsRow}>
          <TouchableOpacity
            style={[S.flagBtn, winnerDiscardedOkey && S.flagBtnActive]}
            onPress={() => setWinnerDiscardedOkey(v => !v)}
          >
            <Text style={[S.flagBtnTxt, winnerDiscardedOkey && S.flagBtnTxtActive]}>
              🏆 Okey abgeworfen (Okey atmak)
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[S.flagBtn, winnerPairedOnly && S.flagBtnActive]}
            onPress={() => setWinnerPairedOnly(v => !v)}
          >
            <Text style={[S.flagBtnTxt, winnerPairedOnly && S.flagBtnTxtActive]}>
              👥 Paare (Çifte bitmek)
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Tile rack */}
      <View style={S.rackSection}>
        <Text style={S.rackLabel}>Deine Steine ({hand.length}/15)</Text>
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={S.rackScroll}
        >
          {hand.map((tile, i) => (
            <TileView
              key={`${tile.color}-${tile.number}-${i}`}
              tile={tile}
              selected={selectedTileIndex === i}
              onPress={() => handleTilePress(i)}
              gösterge={gösterge}
            />
          ))}
        </ScrollView>
      </View>

      {/* Actions */}
      <View style={S.actions}>
        <TouchableOpacity
          style={[S.submitBtn, hand.length !== 15 && S.btnDisabled]}
          onPress={handleSubmitHand}
          disabled={hand.length !== 15}
        >
          <Text style={S.submitBtnTxt}>
            ✅ Hand einreichen &amp; auswerten
          </Text>
        </TouchableOpacity>

        <View style={S.secondaryRow}>
          <TouchableOpacity
            style={[S.secondaryBtn, selectedTileIndex === null && S.btnDisabled]}
            onPress={handleDiscard}
            disabled={selectedTileIndex === null}
          >
            <Text style={S.secondaryBtnTxt}>🗑 Abwerfen</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[S.secondaryBtn, hand.length >= 15 && S.btnDisabled]}
            onPress={handleDraw}
            disabled={hand.length >= 15}
          >
            <Text style={S.secondaryBtnTxt}>➕ Ziehen</Text>
          </TouchableOpacity>
        </View>

        {selectedTileIndex !== null && (
          <Text style={S.selectedHint}>
            Stein #{selectedTileIndex + 1} ausgewählt — "Abwerfen" zum Entfernen
          </Text>
        )}
      </View>
    </View>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────
const S = StyleSheet.create({
  container:    { flex: 1, backgroundColor: '#0f0f1a' },
  centered:     { flex: 1, backgroundColor: '#0f0f1a', justifyContent: 'center', alignItems: 'center', gap: 16 },
  loadingTxt:   { color: 'rgba(255,255,255,0.6)', fontSize: 15 },

  header:       { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  backTxt:      { color: '#e94560', fontSize: 26 },
  headerTitle:  { color: '#fff', fontSize: 18, fontWeight: '700' },
  turnBadge:    { backgroundColor: 'rgba(39,174,96,0.2)', paddingHorizontal: 10, paddingVertical: 4, borderRadius: 10, borderWidth: 1, borderColor: 'rgba(39,174,96,0.4)' },
  turnTxt:      { color: '#27ae60', fontSize: 12, fontWeight: '700' },

  göstergeBanner:{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12, backgroundColor: 'rgba(233,69,96,0.1)', gap: 16 },
  göstergeGroup:{ flexDirection: 'row', alignItems: 'center', gap: 8 },
  okeyGroup:    { flexDirection: 'row', alignItems: 'center', gap: 6 },
  göstergeLbl:  { color: 'rgba(255,255,255,0.5)', fontSize: 12 },
  göstergeTile: { width: 36, height: 50, borderRadius: 6, justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: 'rgba(255,255,255,0.2)' },
  göstergeTileTxt:{ color: '#fff', fontSize: 20, fontWeight: '900' },
  okeyTile:     { borderColor: '#f1c40f', borderWidth: 2 },
  okeyHint:     { color: '#f1c40f', fontSize: 16 },
  renkliTag:    { marginLeft: 'auto', color: '#e94560', fontSize: 12, fontWeight: '800', backgroundColor: 'rgba(233,69,96,0.15)', paddingHorizontal: 8, paddingVertical: 3, borderRadius: 6 },

  flagsBanner:  { paddingHorizontal: 16, paddingVertical: 10, backgroundColor: 'rgba(255,255,255,0.04)', borderBottomWidth: 1, borderBottomColor: 'rgba(255,255,255,0.06)' },
  flagsLabel:   { color: 'rgba(255,255,255,0.4)', fontSize: 11, marginBottom: 6, textTransform: 'uppercase', letterSpacing: 1 },
  flagsRow:     { flexDirection: 'row', gap: 8 },
  flagBtn:      { flex: 1, backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 8, paddingHorizontal: 8, paddingVertical: 6, borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)' },
  flagBtnActive:{ backgroundColor: 'rgba(39,174,96,0.2)', borderColor: '#27ae60' },
  flagBtnTxt:   { color: 'rgba(255,255,255,0.5)', fontSize: 11, fontWeight: '600' },
  flagBtnTxtActive:{ color: '#27ae60' },

  rackSection:  { paddingTop: 12 },
  rackLabel:    { color: 'rgba(255,255,255,0.5)', fontSize: 12, paddingHorizontal: 20, marginBottom: 8 },
  rackScroll:   { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 8, gap: 8 },

  tile:         { width: 52, height: 72, borderRadius: 8, justifyContent: 'center', alignItems: 'center', borderWidth: 2, borderColor: 'rgba(255,255,255,0.2)', marginHorizontal: 2 },
  tileSmall:    { width: 36, height: 50, borderRadius: 6, justifyContent: 'center', alignItems: 'center', borderWidth: 1, borderColor: 'rgba(255,255,255,0.2)', marginHorizontal: 1 },
  tileSelected: { borderColor: '#f1c40f', borderWidth: 3, transform: [{ scale: 1.08 }] },
  tileOkey:     { borderColor: '#f1c40f', borderWidth: 2 },
  tileTxt:      { color: '#fff', fontSize: 24, fontWeight: '900', textShadowColor: 'rgba(0,0,0,0.5)', textShadowOffset: { width: 1, height: 1 }, textShadowRadius: 2 },
  tileTxtSmall: { color: '#fff', fontSize: 16, fontWeight: '900' },
  tileTxtOkey:  { color: '#f1c40f', fontSize: 20 },

  actions:      { paddingHorizontal: 20, paddingVertical: 16, gap: 10 },
  secondaryRow: { flexDirection: 'row', gap: 10 },
  submitBtn:    { backgroundColor: '#27ae60', borderRadius: 12, paddingVertical: 16 },
  submitBtnTxt: { color: '#fff', fontSize: 16, fontWeight: '800', textAlign: 'center' },
  secondaryBtn:{ flex: 1, backgroundColor: 'rgba(255,255,255,0.08)', borderRadius: 12, paddingVertical: 14, borderWidth: 1, borderColor: 'rgba(255,255,255,0.12)', alignItems: 'center' },
  secondaryBtnTxt:{ color: '#fff', fontSize: 15, fontWeight: '600', textAlign: 'center' },
  btnDisabled:  { opacity: 0.4 },
  selectedHint:{ textAlign: 'center', color: 'rgba(241,196,15,0.7)', fontSize: 12, marginTop: 2 },
});
