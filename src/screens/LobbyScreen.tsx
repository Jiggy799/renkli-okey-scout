/**
 * OkeyScout — Lobby Screen
 * src/screens/LobbyScreen.tsx
 *
 * Shows the 4-player table lobby with Supabase Realtime updates.
 *
 * Flow:
 *   1. Display player list (from table_players via Realtime subscription)
 *   2. Creator can select the Gösterge tile (opens GöstergePickerScreen)
 *   3. Other players confirm the Gösterge tile
 *   4. Once gösterge is confirmed by another player → Round starts
 *
 * Realtime subscriptions:
 *   • table_players → live player list
 *   • tables.status → lobby → playing transition
 *   • rounds.gösterge_confirmed → round start trigger
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity,
  ActivityIndicator, Alert, ScrollView,
} from 'react-native';
import type { TileColor } from '../utils/okeyEngine';
import {
  subscribeToTablePlayers,
  subscribeToTableStatus,
  subscribeToGöstergeConfirmation,
  getSupabase,
  type GöstergeTile,
  type Tables,
} from '../services/supabase';

export type Player = {
  playerId:  string;
  username:  string;
  avatarUrl: string | null;
  seatIndex: number;
  isReady:   boolean;
  isCreator: boolean;
};

type Props = {
  navigation: any; // navigation prop for programmatic navigation
  tableId:    string;
  userId:     string;
  /** Username of the current user */
  username:   string;
  onStartRound: (gösterge: GöstergeTile) => void;
  onLeaveTable: () => void;
  onGoBack:    () => void;
};

// ─────────────────────────────────────────────────────────────────────────────
// Gösterge Picker Modal
// ─────────────────────────────────────────────────────────────────────────────

type GöstergePickerProps = {
  visible:   boolean;
  onSelect:  (gösterge: GöstergeTile) => void;
  onCancel:  () => void;
  isCreator: boolean;
};

const COLORS: TileColor[] = ['RED', 'BLACK', 'BLUE', 'YELLOW'];

function GöstergePicker({ visible, onSelect, onCancel, isCreator }: GöstergePickerProps) {
  if (!visible) return null;

  return (
    <View style={S.modalOverlay}>
      <View style={S.modal}>
        <Text style={S.modalTitle}>
          {isCreator ? '🎴 Gösterge wählen' : '✓ Gösterge bestätigen'}
        </Text>
        <Text style={S.modalSub}>
          {isCreator
            ? 'Wähle die aufgedeckte Pool-Karte (Gösterge).'
            : 'Bestätige die Gösterge-Karte des Tisch-Erstellers.'}
        </Text>

        <View style={S.göstergeGrid}>
          {COLORS.map(color => (
            <View key={color} style={S.colorRow}>
              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13].map(num => (
                <TouchableOpacity
                  key={`${color}-${num}`}
                  style={[S.gTile, { backgroundColor: tileColorToHex(color) }]}
                  onPress={() => onSelect({ color, number: num })}
                >
                  <Text style={S.gTileTxt}>{num}</Text>
                </TouchableOpacity>
              ))}
            </View>
          ))}
        </View>

        <TouchableOpacity style={S.modalCancel} onPress={onCancel}>
          <Text style={S.modalCancelTxt}>Abbrechen</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

function tileColorToHex(color: TileColor): string {
  switch (color) {
    case 'RED':    return '#c0392b';
    case 'BLACK':  return '#1a1a1a';
    case 'BLUE':   return '#2980b9';
    case 'YELLOW': return '#f1c40f';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LobbyScreen
// ─────────────────────────────────────────────────────────────────────────────

export default function LobbyScreen({
  navigation,
  tableId, userId, username,
  onStartRound, onLeaveTable, onGoBack,
}: Props) {
  const [players,     setPlayers]     = useState<Player[]>([]);
  const [tableStatus, setTableStatus] = useState<Tables['status']>('lobby');
  const [gösterge,   setGösterge]   = useState<GöstergeTile | null>(null);
  const [göstergeBy, setGöstergeBy]  = useState<string | null>(null);
  const [göstergeConfirmed, setGöstergeConfirmed] = useState(false);
  const [showPicker, setShowPicker]   = useState(false);
  const [loading,    setLoading]     = useState(true);

  const isCreator = players.find(p => p.playerId === userId)?.isCreator ?? false;

  // ── Load initial player list ──────────────────────────────────────────
  useEffect(() => {
    async function loadPlayers() {
      const { data, error } = await getSupabase()
        .from('table_players')
        .select('player_id, seat_index, is_ready, is_creator, profiles(username, avatar_url)')
        .eq('table_id', tableId)
        .order('seat_index', { ascending: true });

      if (!error && data) {
        // data items have shape: table_players columns + joined profiles
        const mapped: Player[] = (data as Array<{
          player_id: string;
          seat_index: number;
          is_ready: boolean;
          is_creator: boolean;
          profiles: { username: string; avatar_url: string | null };
        }>).map(row => ({
          playerId:  row.player_id,
          seatIndex: row.seat_index,
          isReady:   row.is_ready,
          isCreator: row.is_creator,
          username:  row.profiles?.username ?? 'Unbekannt',
          avatarUrl: row.profiles?.avatar_url ?? null,
        }));
        setPlayers(mapped);
      }
      setLoading(false);
    }

    loadPlayers();
  }, [tableId]);

  // ── Realtime: table_players ───────────────────────────────────────────
  useEffect(() => {
    const unsub = subscribeToTablePlayers(tableId, async (event) => {
      // Reload full player list on any change
      const { data } = await getSupabase()
        .from('table_players')
        .select('player_id, seat_index, is_ready, is_creator, profiles(username, avatar_url)')
        .eq('table_id', tableId)
        .order('seat_index', { ascending: true });

      if (data) {
        const mapped: Player[] = (data as Array<{
          player_id: string;
          seat_index: number;
          is_ready: boolean;
          is_creator: boolean;
          profiles: { username: string; avatar_url: string | null };
        }>).map(row => ({
          playerId:  row.player_id,
          seatIndex: row.seat_index,
          isReady:   row.is_ready,
          isCreator: row.is_creator,
          username:  row.profiles?.username ?? 'Unbekannt',
          avatarUrl: row.profiles?.avatar_url ?? null,
        }));
        setPlayers(mapped);
      }
    });

    return () => { unsub(); };
  }, [tableId]);

  // ── Realtime: table status ────────────────────────────────────────────
  useEffect(() => {
    const unsub = subscribeToTableStatus(tableId, async (status) => {
      setTableStatus(status);
      if (status === 'playing') {
        // Fetch gösterge from the active round if not yet in local state
        let göstergeToUse = gösterge;
        if (!göstergeToUse) {
          const { data: round } = await getSupabase()
            .from('rounds')
            .select('gösterge_tile')
            .eq('table_id', tableId)
            .eq('status', 'playing')
            .single();
          göstergeToUse = round?.gösterge_tile ?? göstergeToUse;
        }
        navigation.replace('Game', {
          tableId,
          gösterge: göstergeToUse ?? { color: 'RED', number: 5 },
          userId,
        });
      }
    });
    return () => { unsub(); };
  }, [tableId]);

  // ── Realtime: gösterge confirmation ──────────────────────────────────
  useEffect(() => {
    const unsub = subscribeToGöstergeConfirmation(tableId, (göstergeTile) => {
      setGöstergeConfirmed(true);
      onStartRound(göstergeTile);
    });
    return () => { unsub(); };
  }, [tableId]);

  // ── Creator selects gösterge ─────────────────────────────────────────
  const handleGöstergeSelect = useCallback(async (tile: GöstergeTile) => {
    setGösterge(tile);
    setGöstergeBy(userId);
    setShowPicker(false);

    // Insert or update the gösterge tile in the round record
    const { error } = await getSupabase()
      .from('rounds')
      .upsert({
        table_id:           tableId,
        round_number:        1,
        gösterge_tile:       tile,
        gösterge_player_id: userId,
        gösterge_confirmed:  false,
        gösterge_confirmed_by: null,
        status:              'gösterge_selection',
      }, {
        onConflict: 'table_id,round_number',
      });

    if (error) {
      Alert.alert('Fehler', 'Gösterge konnte nicht gespeichert werden.');
      setGösterge(null);
    }
  }, [tableId, userId]);

  // ── Non-creator confirms gösterge ────────────────────────────────────
  const handleGöstergeConfirm = useCallback(async () => {
    if (!gösterge || !göstergeBy) return;

    const { error } = await getSupabase()
      .from('rounds')
      .update({
        gösterge_confirmed:   true,
        gösterge_confirmed_by: userId,
        status:               'playing',
        started_at:           new Date().toISOString(),
      })
      .eq('table_id', tableId)
      .eq('round_number', 1);

    if (error) {
      Alert.alert('Fehler', 'Bestätigung fehlgeschlagen.');
    }
  }, [gösterge, göstergeBy, tableId, userId]);

  // ── Toggle ready ─────────────────────────────────────────────────────
  const handleToggleReady = useCallback(async () => {
    const current = players.find(p => p.playerId === userId);
    if (!current) return;

    const { error } = await getSupabase()
      .from('table_players')
      .update({ is_ready: !current.isReady })
      .eq('player_id', userId)
      .eq('table_id', tableId);

    if (error) {
      Alert.alert('Fehler', 'Bereit-Status konnte nicht geändert werden.');
    }
  }, [players, userId, tableId]);

  // ── Leave table ──────────────────────────────────────────────────────
  const handleLeave = useCallback(async () => {
    Alert.alert('Tisch verlassen?', 'Du verlässt diesen Tisch.', [
      { text: 'Abbrechen', style: 'cancel' },
      {
        text: 'Verlassen',
        style: 'destructive',
        onPress: async () => {
          await getSupabase()
            .from('table_players')
            .delete()
            .eq('player_id', userId)
            .eq('table_id', tableId);
          onLeaveTable();
        },
      },
    ]);
  }, [userId, tableId, onLeaveTable]);

  // ── Start round (creator, all 4 ready + gösterge confirmed) ─────────
  const allReady = players.length === 4 && players.every(p => p.isReady);

  const handleStartRound = useCallback(async () => {
    if (!allReady || !gösterge || !göstergeConfirmed) return;

    await getSupabase()
      .from('tables')
      .update({ status: 'playing', current_round: 1 })
      .eq('id', tableId);

    onStartRound(gösterge);
  }, [allReady, gösterge, göstergeConfirmed, tableId, onStartRound]);

  // ── Render ────────────────────────────────────────────────────────────
  if (loading) {
    return (
      <View style={S.centered}>
        <ActivityIndicator size="large" color="#e94560" />
        <Text style={S.hint}>Lobby wird geladen…</Text>
      </View>
    );
  }

  const SEAT_EMOJI = ['1️⃣', '2️⃣', '3️⃣', '4️⃣'];

  return (
    <View style={S.container}>
      {/* Header */}
      <View style={S.header}>
        <TouchableOpacity onPress={handleLeave}>
          <Text style={S.backTxt}>←</Text>
        </TouchableOpacity>
        <Text style={S.headerTitle}>Tisch {tableId}</Text>
        <View style={{ width: 32 }} />
      </View>

      {/* Table code */}
      <View style={S.codeBanner}>
        <Text style={S.codeLabel}>Tisch-Code</Text>
        <Text style={S.codeValue}>{tableId}</Text>
      </View>

      <ScrollView style={S.body} contentContainerStyle={{ paddingBottom: 32 }}>
        {/* Players */}
        <Text style={S.sectionTitle}>Spieler ({players.length}/4)</Text>

        {Array.from({ length: 4 }, (_, i) => {
          const player = players.find(p => p.seatIndex === i);
          return (
            <View key={i} style={[S.playerCard, player && S.playerCardActive]}>
              <View style={S.seatBadge}>
                <Text style={S.seatEmoji}>{SEAT_EMOJI[i]}</Text>
              </View>
              {player ? (
                <>
                  <View style={S.playerInfo}>
                    <Text style={S.playerName}>
                      {player.username}
                      {player.playerId === userId && ' (Du)'}
                      {player.isCreator && ' 👑'}
                    </Text>
                    <Text style={S.playerStatus}>
                      {player.isReady ? '✅ Bereit' : '⏳ Nicht bereit'}
                    </Text>
                  </View>
                  {player.playerId === userId && (
                    <TouchableOpacity
                      style={[S.readyBtn, player.isReady && S.readyBtnActive]}
                      onPress={handleToggleReady}
                    >
                      <Text style={S.readyBtnTxt}>
                        {player.isReady ? 'Bereit ✓' : 'Bereit?'}
                      </Text>
                    </TouchableOpacity>
                  )}
                </>
              ) : (
                <Text style={S.waitingTxt}>Warte auf Spieler…</Text>
              )}
            </View>
          );
        })}

        {/* Gösterge section */}
        <Text style={S.sectionTitle}>Gösterge</Text>

        {gösterge ? (
          <View style={S.göstergeCard}>
            <View style={[S.göstergeTile, { backgroundColor: tileColorToHex(gösterge.color as TileColor) }]}>
              <Text style={S.göstergeTileTxt}>{gösterge.number}</Text>
            </View>
            <View style={{ flex: 1, marginLeft: 12 }}>
              <Text style={S.playerName}>
                Gewählt von: {players.find(p => p.playerId === göstergeBy)?.username ?? 'Unbekannt'}
              </Text>
              {göstergeConfirmed ? (
                <Text style={S.confirmedTxt}>✅ Bestätigt!</Text>
              ) : (
                <>
                  <Text style={S.playerStatus}>Warte auf Bestätigung…</Text>
                  {!isCreator && göstergeBy !== userId && (
                    <TouchableOpacity style={S.confirmBtn} onPress={handleGöstergeConfirm}>
                      <Text style={S.confirmBtnTxt}>✓ Bestätigen</Text>
                    </TouchableOpacity>
                  )}
                </>
              )}
            </View>
          </View>
        ) : (
          <View style={S.göstergeCard}>
            <Text style={S.hint}>Gösterge wurde noch nicht gewählt.</Text>
            {isCreator && (
              <TouchableOpacity
                style={S.pickBtn}
                onPress={() => setShowPicker(true)}
              >
                <Text style={S.pickBtnTxt}>🎴 Gösterge wählen</Text>
              </TouchableOpacity>
            )}
          </View>
        )}

        {/* Start / waiting */}
        {isCreator && (
          <TouchableOpacity
            style={[
              S.startBtn,
              (!allReady || !gösterge || göstergeConfirmed) && S.startBtnDis,
            ]}
            onPress={handleStartRound}
            disabled={!allReady || !gösterge || göstergeConfirmed}
          >
            <Text style={S.startBtnTxt}>
              {!allReady
                ? `⏳ Warte auf Spieler (${players.length}/4)`
                : !gösterge
                ? '🎴 Gösterge wählen'
                : !göstergeConfirmed
                ? '⏳ Warte auf Gösterge-Bestätigung'
                : '🚀 Runde starten'}
            </Text>
          </TouchableOpacity>
        )}

        {!isCreator && (
          <Text style={S.waitingHint}>
            {tableStatus === 'playing'
              ? '🔄 Runde startet…'
              : '⏳ Warte auf Tisch-Ersteller…'}
          </Text>
        )}
      </ScrollView>

      {/* Gösterge Picker Modal */}
      <GöstergePicker
        visible={showPicker}
        onSelect={handleGöstergeSelect}
        onCancel={() => setShowPicker(false)}
        isCreator={isCreator}
      />
    </View>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────────────────────────────────────

const S = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#0f0f1a' },
  centered:  { flex: 1, backgroundColor: '#0f0f1a', justifyContent: 'center', alignItems: 'center', gap: 16 },
  hint:      { color: 'rgba(255,255,255,0.62)', fontSize: 15, textAlign: 'center', paddingHorizontal: 32 },
  waitingHint:{ color: 'rgba(255,255,255,0.48)', fontSize: 14, textAlign: 'center', marginTop: 24 },

  header:    { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 60, paddingHorizontal: 20, paddingBottom: 8 },
  backTxt:   { color: '#fff', fontSize: 22 },
  headerTitle:{ color: '#fff', fontSize: 18, fontWeight: '700' },

  codeBanner:{ alignItems: 'center', paddingVertical: 12, backgroundColor: 'rgba(233,69,96,0.12)' },
  codeLabel: { color: 'rgba(255,255,255,0.5)', fontSize: 12 },
  codeValue: { color: '#e94560', fontSize: 28, fontWeight: '900', letterSpacing: 8 },

  body:      { flex: 1, paddingHorizontal: 20, paddingTop: 16 },

  sectionTitle:{ color: '#fff', fontSize: 16, fontWeight: '700', marginBottom: 12, marginTop: 8 },

  playerCard:{ flexDirection: 'row', alignItems: 'center', backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 14, marginBottom: 10, minHeight: 72, borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' },
  playerCardActive:{ borderColor: '#e94560' },
  seatBadge: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', justifyContent: 'center', alignItems: 'center', marginRight: 12 },
  seatEmoji: { fontSize: 20 },
  playerInfo:{ flex: 1 },
  playerName:{ color: '#fff', fontSize: 15, fontWeight: '600' },
  playerStatus:{ color: 'rgba(255,255,255,0.5)', fontSize: 13, marginTop: 2 },
  waitingTxt:{ color: 'rgba(255,255,255,0.28)', fontStyle: 'italic', fontSize: 14 },
  readyBtn:  { backgroundColor: 'rgba(39,174,96,0.2)', borderRadius: 8, paddingHorizontal: 12, paddingVertical: 6, borderWidth: 1, borderColor: 'rgba(39,174,96,0.4)' },
  readyBtnActive:{ backgroundColor: '#27ae60', borderColor: '#27ae60' },
  readyBtnTxt:{ color: '#fff', fontSize: 13, fontWeight: '600' },

  göstergeCard:{ backgroundColor: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 16, marginBottom: 12, flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderColor: 'rgba(255,255,255,0.08)' },
  göstergeTile:{ width: 52, height: 72, borderRadius: 8, backgroundColor: '#c0392b', justifyContent: 'center', alignItems: 'center' },
  göstergeTileTxt:{ color: '#fff', fontSize: 26, fontWeight: '900' },
  confirmedTxt:{ color: '#27ae60', fontSize: 14, fontWeight: '600', marginTop: 4 },
  confirmBtn: { backgroundColor: '#27ae60', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 7, marginTop: 6, alignSelf: 'flex-start' },
  confirmBtnTxt:{ color: '#fff', fontSize: 13, fontWeight: '700' },
  pickBtn:    { backgroundColor: '#e94560', borderRadius: 8, paddingHorizontal: 14, paddingVertical: 7, marginTop: 6 },
  pickBtnTxt: { color: '#fff', fontSize: 13, fontWeight: '700' },

  startBtn:   { backgroundColor: '#e94560', borderRadius: 14, paddingVertical: 18, marginTop: 16 },
  startBtnDis: { opacity: 0.4 },
  startBtnTxt: { color: '#fff', fontSize: 17, fontWeight: '800', textAlign: 'center' },

  // Modal
  modalOverlay:{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.8)', justifyContent: 'center', alignItems: 'center', zIndex: 100 },
  modal:       { backgroundColor: '#1a1a2e', borderRadius: 20, padding: 24, width: '92%', maxHeight: '80%' },
  modalTitle:   { color: '#fff', fontSize: 20, fontWeight: '800', marginBottom: 8 },
  modalSub:     { color: 'rgba(255,255,255,0.62)', fontSize: 14, marginBottom: 20 },
  göstergeGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginBottom: 20 },
  colorRow:     { width: '100%', flexDirection: 'row', gap: 6, flexWrap: 'wrap' },
  gTile:       { width: 40, height: 52, borderRadius: 6, justifyContent: 'center', alignItems: 'center', borderWidth: 1, borderColor: 'rgba(0,0,0,0.3)' },
  gTileTxt:    { color: '#fff', fontSize: 16, fontWeight: '800', textShadowColor: 'rgba(0,0,0,0.5)', textShadowOffset: { width: 1, height: 1 }, textShadowRadius: 2 },
  modalCancel:  { backgroundColor: 'rgba(255,255,255,0.08)', borderRadius: 10, paddingVertical: 12 },
  modalCancelTxt:{ color: 'rgba(255,255,255,0.6)', fontSize: 15, fontWeight: '600', textAlign: 'center' },
});
