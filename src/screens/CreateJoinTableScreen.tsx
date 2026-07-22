/**
 * OkeyScout — Create or Join Table Screen
 * src/screens/CreateJoinTableScreen.tsx
 *
 * Features:
 *   • Create Table  → generates random 4-digit code → QR displayed → Supabase insert
 *   • Join by Code  → manual 4-digit entry → Supabase lookup
 *   • Scan QR       → inline camera overlay (expo-camera built-in barcode scanning)
 *
 * QR code format: okey://join/<TABLE_CODE>
 */

import { useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, TouchableOpacity,
  TextInput, ActivityIndicator, Alert, Dimensions,
} from 'react-native';
import QRCode from 'react-native-qrcode-svg';
import { getSupabase } from '../services/supabase';
import type { Tables, TablePlayers } from '../services/supabase';
import QRScannerOverlay from '../components/QRScannerOverlay';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function generateTableCode(): string {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Props
// ─────────────────────────────────────────────────────────────────────────────

type Props = {
  userId: string;
  onJoinedTable: (tableId: string, playerId: string) => void;
  onGoBack: () => void;
};

// ─────────────────────────────────────────────────────────────────────────────
// CreateJoinTableScreen
// ─────────────────────────────────────────────────────────────────────────────

export default function CreateJoinTableScreen({ userId, onJoinedTable, onGoBack }: Props) {
  const [mode,      setMode]      = useState<'home' | 'create' | 'join'>('home');
  const [code,      setCode]      = useState('');
  const [newCode,   setNewCode]   = useState<string | null>(null);
  const [loading,   setLoading]   = useState(false);
  const [error,     setError]     = useState<string | null>(null);
  const [showQRScanner, setShowQRScanner] = useState(false);

  const qrValue = newCode ? `okey://join/${newCode}` : null;

  // ── Create a new table ────────────────────────────────────────────────

  const handleCreate = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const tableCode = generateTableCode();
      const { error: insertErr } = await getSupabase()
        .from('tables')
        .insert({
          id:         tableCode,
          status:     'lobby',
          created_by: userId,
        });

      if (insertErr) throw insertErr;

      // Seat creator at seat 0
      const { error: playerErr } = await getSupabase()
        .from('table_players')
        .insert({
          table_id:   tableCode,
          player_id:  userId,
          seat_index: 0,
          is_ready:   false,
          is_creator: true,
        });

      if (playerErr) throw playerErr;

      setNewCode(tableCode);
      setMode('create');
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, [userId]);

  // ── Join by code ──────────────────────────────────────────────────────

  const handleJoin = useCallback(async () => {
    const trimmed = code.trim();
    if (trimmed.length !== 4 || !/^\d{4}$/.test(trimmed)) {
      setError('Bitte einen gültigen 4-stelligen Code eingeben.');
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const { data: table, error: tableErr } = await getSupabase()
        .from('tables')
        .select('id, status')
        .eq('id', trimmed)
        .single();

      if (tableErr || !table) throw new Error('Tisch nicht gefunden.');

      if (table.status !== 'lobby') {
        throw new Error('Dieser Tisch hat das Lobby bereits verlassen.');
      }

      const { data: players } = await getSupabase()
        .from('table_players')
        .select('seat_index')
        .eq('table_id', trimmed)
        .order('seat_index', { ascending: true });

      if (players && players.length >= 4) {
        throw new Error('Dieser Tisch ist bereits voll (4 Spieler).');
      }

      const takenSeats = new Set((players ?? []).map((p: { seat_index: number }) => p.seat_index));
      let seatIndex = 1;
      for (let i = 1; i <= 3; i++) {
        if (!takenSeats.has(i)) { seatIndex = i; break; }
      }

      const { error: joinErr } = await getSupabase()
        .from('table_players')
        .insert({
          table_id:   trimmed,
          player_id:  userId,
          seat_index: seatIndex,
          is_ready:   false,
          is_creator: false,
        });

      if (joinErr) throw joinErr;

      onJoinedTable(trimmed, userId);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, [code, userId, onJoinedTable]);

  // ── QR code scanned ────────────────────────────────────────────────────

  const handleQRScanned = useCallback((tableCode: string) => {
    setShowQRScanner(false);
    setCode(tableCode);
    // Auto-trigger join
    setTimeout(() => {
      setLoading(true);
      setError(null);

      getSupabase()
        .from('tables')
        .select('id, status')
        .eq('id', tableCode)
        .single()
        .then(({ data: table, error: tableErr }: { data: Tables | null; error: any }) => {
          if (tableErr || !table) throw new Error('Tisch nicht gefunden.');
          if (table.status !== 'lobby') throw new Error('Dieser Tisch hat das Lobby bereits verlassen.');

          return getSupabase()
            .from('table_players')
            .select('seat_index')
            .eq('table_id', tableCode)
            .order('seat_index', { ascending: true });
        })
        .then(({ data: players }: { data: TablePlayers[] | null }) => {
          const takenSeats = new Set((players ?? []).map((p: { seat_index: number }) => p.seat_index));
          let seatIndex = 1;
          for (let i = 1; i <= 3; i++) {
            if (!takenSeats.has(i)) { seatIndex = i; break; }
          }
          return getSupabase()
            .from('table_players')
            .insert({
              table_id:   tableCode,
              player_id:  userId,
              seat_index: seatIndex,
              is_ready:   false,
              is_creator: false,
            });
        })
        .then(() => onJoinedTable(tableCode, userId))
        .catch((err: unknown) => {
          const msg = err instanceof Error ? err.message : String(err);
          setError(msg);
          setLoading(false);
        });
    }, 100);
  }, [userId, onJoinedTable]);

  // ── Create mode ────────────────────────────────────────────────────────

  if (mode === 'create' && newCode) {
    return (
      <View style={S.centered}>
        <Text style={S.title}>Dein Tisch</Text>
        <Text style={S.code}>{newCode}</Text>

        <View style={S.qrContainer}>
          {qrValue && (
            <QRCode
              value={qrValue}
              size={Dimensions.get('window').width * 0.55}
              backgroundColor="#ffffff"
              color="#000000"
            />
          )}
        </View>

        <Text style={S.hint}>
          Spieler können den QR-Code scannen oder den Code{' '}
          <Text style={S.codeHighlight}>{newCode}</Text> manuell eingeben.
        </Text>

        <Text style={S.waitingTxt}>Warte auf Spieler…</Text>
        <Text style={S.smallHint}>
          Du wirst automatisch zum Spiel weitergeleitet,
          wenn 4 Spieler beigetreten sind.
        </Text>

        {error && <Text style={S.errorTxt}>{error}</Text>}
      </View>
    );
  }

  // ── Default: home (Create or Join) ────────────────────────────────────

  return (
    <View style={S.container}>
      <QRScannerOverlay
        visible={showQRScanner}
        onCodeScanned={handleQRScanned}
        onClose={() => setShowQRScanner(false)}
      />

      <View style={S.header}>
        <TouchableOpacity onPress={onGoBack}>
          <Text style={S.backTxt}>←</Text>
        </TouchableOpacity>
        <Text style={S.headerTitle}>Tisch beitreten</Text>
        <View style={{ width: 32 }} />
      </View>

      <View style={S.body}>
        {error ? (
          <View style={S.errorBanner}>
            <Text style={S.errorBannerTxt}>{error}</Text>
          </View>
        ) : null}

        {/* Create Table */}
        <TouchableOpacity
          style={[S.primaryBtn, loading && S.btnDisabled]}
          onPress={handleCreate}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={S.primaryBtnTxt}>🎯  Neuen Tisch erstellen</Text>
          )}
        </TouchableOpacity>

        <View style={S.divider}>
          <View style={S.dividerLine} />
          <Text style={S.dividerTxt}>oder</Text>
          <View style={S.dividerLine} />
        </View>

        {/* Join by Code */}
        <Text style={S.sectionTitle}>Code eingeben</Text>
        <TextInput
          style={S.codeInput}
          value={code}
          onChangeText={setCode}
          placeholder="0000"
          placeholderTextColor="rgba(255,255,255,0.3)"
          keyboardType="number-pad"
          maxLength={4}
        />
        <TouchableOpacity
          style={[S.primaryBtn, (!code.trim() || loading) && S.btnDisabled]}
          onPress={handleJoin}
          disabled={!code.trim() || loading}
        >
          <Text style={S.primaryBtnTxt}>🔑  Beitreten</Text>
        </TouchableOpacity>

        <View style={S.divider}>
          <View style={S.dividerLine} />
          <Text style={S.dividerTxt}>oder</Text>
          <View style={S.dividerLine} />
        </View>

        {/* Scan QR */}
        <TouchableOpacity
          style={S.secondaryBtn}
          onPress={() => setShowQRScanner(true)}
        >
          <Text style={S.secondaryBtnTxt}>📷  QR-Code scannen</Text>
        </TouchableOpacity>

        <TouchableOpacity style={S.linkBtn} onPress={onGoBack}>
          <Text style={S.linkBtnTxt}>Zurück zum Menü</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────────────────────────────────────

const S = StyleSheet.create({
  container:       { flex: 1, backgroundColor: '#0f0f1a' },
  centered:         { flex: 1, backgroundColor: '#0f0f1a', justifyContent: 'center', alignItems: 'center', gap: 16, padding: 32 },
  header:           { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 60, paddingHorizontal: 20, paddingBottom: 16 },
  headerTitle:      { color: '#fff', fontSize: 18, fontWeight: '600' },
  backTxt:          { color: '#e94560', fontSize: 28 },
  body:             { flex: 1, padding: 24, gap: 12 },
  title:            { color: '#fff', fontSize: 22, fontWeight: '700' },
  code:             { color: '#e94560', fontSize: 48, fontWeight: '700', letterSpacing: 8 },
  codeHighlight:    { color: '#e94560', fontWeight: '700' },
  qrContainer:      { marginVertical: 8, padding: 16, backgroundColor: '#fff', borderRadius: 16 },
  hint:             { color: 'rgba(255,255,255,0.6)', fontSize: 14, textAlign: 'center', lineHeight: 20 },
  smallHint:        { color: 'rgba(255,255,255,0.4)', fontSize: 12, textAlign: 'center' },
  waitingTxt:       { color: '#fff', fontSize: 16, fontWeight: '600', marginTop: 8 },
  sectionTitle:     { color: 'rgba(255,255,255,0.5)', fontSize: 12, fontWeight: '600', textTransform: 'uppercase', letterSpacing: 1, marginTop: 8 },
  codeInput:        { backgroundColor: 'rgba(255,255,255,0.08)', borderRadius: 12, paddingHorizontal: 20, paddingVertical: 14, color: '#fff', fontSize: 28, letterSpacing: 8, textAlign: 'center', borderWidth: 1, borderColor: 'rgba(255,255,255,0.12)' },
  primaryBtn:       { backgroundColor: '#e94560', paddingVertical: 16, borderRadius: 14, alignItems: 'center' },
  primaryBtnTxt:    { color: '#fff', fontSize: 17, fontWeight: '600' },
  btnDisabled:      { opacity: 0.5 },
  secondaryBtn:     { backgroundColor: 'rgba(255,255,255,0.08)', paddingVertical: 16, borderRadius: 14, alignItems: 'center', borderWidth: 1, borderColor: 'rgba(255,255,255,0.12)' },
  secondaryBtnTxt:  { color: '#fff', fontSize: 17 },
  divider:          { flexDirection: 'row', alignItems: 'center', gap: 12, marginVertical: 4 },
  dividerLine:      { flex: 1, height: 1, backgroundColor: 'rgba(255,255,255,0.1)' },
  dividerTxt:       { color: 'rgba(255,255,255,0.3)', fontSize: 12 },
  linkBtn:          { alignItems: 'center', paddingVertical: 8 },
  linkBtnTxt:       { color: 'rgba(255,255,255,0.4)', fontSize: 14 },
  errorBanner:      { backgroundColor: 'rgba(233,69,96,0.15)', borderRadius: 10, paddingHorizontal: 16, paddingVertical: 10, borderWidth: 1, borderColor: 'rgba(233,69,96,0.3)' },
  errorBannerTxt:   { color: '#e94560', fontSize: 13 },
  errorTxt:         { color: '#e94560', fontSize: 13, textAlign: 'center' },
});
