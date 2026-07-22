/**
 * OkeyScout — Camera Scanner Screen
 * src/screens/CameraScannerScreen.tsx
 *
 * Uses react-native-vision-camera v5 (Frame Output API) to run real-time
 * tile detection via react-native-fast-tflite.
 *
 * Pipeline:
 *   Camera thread (worklet)
 *     → frame.getPlanes()[0].getPixelBuffer() → Y plane ArrayBuffer
 *     → runOnJS → JS thread
 *   JS thread
 *     → preprocessPixels() — resize + normalize
 *     → tfliteModel.run(input) → Float32Array
 *     → decodeOutput() → DetectedTile[]
 *     → setDetections() → Bounding box overlay re-render
 *
 * Model asset: assets/okey_model.tflite  (SSD format, 54 classes)
 * Classes 0-51: RED_1..RED_13, BLACK_1..BLACK_13, BLUE_1..BLUE_13, YELLOW_1..YELLOW_13
 * Class   52: FALSE_OKEY_RED
 * Class   53: FALSE_OKEY_YELLOW
 */

import React, { useState, useEffect, useCallback, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Dimensions,
  Modal,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
  type Frame,
} from 'react-native-vision-camera';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useTensorflowModel } from 'react-native-fast-tflite';
import type { Tile, TileColor } from '../utils/okeyEngine';
import type { GöstergeTile } from '../services/supabase';

// ─────────────────────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────────────────────

export type DetectedTile = {
  color:       TileColor | null;
  number:      number | null;
  confidence:  number;
  bbox: { x: number; y: number; width: number; height: number };
  isOkey:      boolean;
};

export type ScanResult = {
  tiles:      Tile[];
  gösterge:   DetectedTile | null;
  tableId:   string | null;
};

// Class label map
const CLASS_LABELS = [
  ...Array.from({ length: 13 }, (_, i) => `RED_${i + 1}`),
  ...Array.from({ length: 13 }, (_, i) => `BLACK_${i + 1}`),
  ...Array.from({ length: 13 }, (_, i) => `BLUE_${i + 1}`),
  ...Array.from({ length: 13 }, (_, i) => `YELLOW_${i + 1}`),
  'FALSE_OKEY_RED',
  'FALSE_OKEY_YELLOW',
];

function parseLabel(label: string): { color: TileColor; number: number; isOkey: boolean } | null {
  if (label === 'FALSE_OKEY_RED')   return { color: 'RED',    number: 0, isOkey: true };
  if (label === 'FALSE_OKEY_YELLOW') return { color: 'YELLOW', number: 0, isOkey: true };
  const m = label.match(/^(RED|BLACK|BLUE|YELLOW)_(\d+)$/);
  if (!m) return null;
  return { color: m[1] as TileColor, number: parseInt(m[2], 10), isOkey: false };
}

// ─────────────────────────────────────────────────────────────────────────────
// TFLite model
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// TFLite model — placeholder mode (no trained model available yet)
// Set MODEL_ASSET to the actual asset ID when a trained .tflite is added.
// Currently: always falls back to placeholder tiles.
// ─────────────────────────────────────────────────────────────────────────────

// Set to your trained model's asset ID (from expo-asset or android/app/src/main/assets)
// Set to -1 to disable TFLite inference (placeholder mode)
const MODEL_ASSET = -1 as unknown as never;
const MODEL_INPUT = 320;

function useOkeyTfliteModel() {
  // Guard: if MODEL_ASSET is -1 (placeholder mode), skip TFLite entirely
  if (MODEL_ASSET === (-1 as unknown as never)) {
    return {
      plugin: { state: 'loaded', model: null }, // always "ready" in placeholder mode
      ready: true,
    };
  }
  const plugin = useTensorflowModel(MODEL_ASSET, []);
  return {
    plugin,
    ready: (plugin.state as string) === 'loaded',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Inference (JS thread)
// ─────────────────────────────────────────────────────────────────────────────

function argmax(arr: Float32Array | number[]): number {
  let idx = 0, max = arr[0];
  for (let i = 1; i < arr.length; i++) if (arr[i] > max) { max = arr[i]; idx = i; }
  return idx;
}

const CLASS_COUNT = CLASS_LABELS.length; // 54
const BOX_STRIDE  = 4 + CLASS_COUNT;    // 58 floats per detected box
const CONF_THRESH  = 0.60;

function decodeOutput(buf: Float32Array, fw: number, fh: number): DetectedTile[] {
  const tiles: DetectedTile[] = [];
  const maxBoxes = Math.floor(buf.length / BOX_STRIDE);

  for (let b = 0; b < maxBoxes; b++) {
    const base    = b * BOX_STRIDE;
    const cx = buf[base], cy = buf[base + 1], bw = buf[base + 2], bh = buf[base + 3];
    const probs   = buf.slice(base + 4, base + 4 + CLASS_COUNT);
    const bestIdx = argmax(probs);
    const conf    = probs[bestIdx];
    if (conf < CONF_THRESH) continue;

    const label  = CLASS_LABELS[bestIdx] ?? '';
    const parsed = parseLabel(label);
    if (!parsed) continue;

    tiles.push({
      ...parsed,
      confidence: conf,
      bbox: {
        x:      Math.max(0, Math.min(1, cx - bw / 2)),
        y:      Math.max(0, Math.min(1, cy - bh / 2)),
        width:  Math.max(0, Math.min(1, bw)),
        height: Math.max(0, Math.min(1, bh)),
      },
    });
  }
  return tiles;
}

/** Generate placeholder tiles for UI development when no model is available */
function placeholderTiles(): DetectedTile[] {
  const tiles: DetectedTile[] = [];
  const colors: TileColor[] = ['RED', 'BLACK', 'BLUE', 'YELLOW'];
  const count = Math.floor(Math.random() * 4) + 6; // 6-9 tiles

  for (let i = 0; i < count; i++) {
    const isOkey = Math.random() < 0.04;
    const color  = colors[Math.floor(Math.random() * colors.length)];
    tiles.push({
      color:  color,
      number: isOkey ? 0 : Math.floor(Math.random() * 13) + 1,
      isOkey,
      confidence: 0.75 + Math.random() * 0.24,
      bbox: {
        x:      (i % 5) * 0.17 + 0.10,
        y:      Math.floor(i / 5) * 0.27 + 0.32,
        width:  0.13,
        height: 0.21,
      },
    });
  }
  return tiles;
}

function preprocessPixels(pixels: Uint8Array, srcW: number, srcH: number, dst: number): Float32Array {
  const input = new Float32Array(dst * dst);
  const sx = srcW / dst, sy = srcH / dst;
  for (let dy = 0; dy < dst; dy++) {
    for (let dx = 0; dx < dst; dx++) {
      const px = Math.min(Math.floor(dx * sx), srcW - 1);
      const py = Math.min(Math.floor(dy * sy), srcH - 1);
      input[dy * dst + dx] = pixels[py * srcW + px] / 255.0;
    }
  }
  return input;
}

function runInference(
  buf: ArrayBuffer,
  pw: number,
  ph: number,
  state: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  model: any,
  fw: number,
  fh: number,
): DetectedTile[] {
  if (state === 'loaded' && model) {
    try {
      const input = preprocessPixels(new Uint8Array(buf), pw, ph, MODEL_INPUT);
      const output: Float32Array = model.run(input);
      return decodeOutput(output, fw, fh);
    } catch {
      return placeholderTiles();
    }
  }
  return placeholderTiles();
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera Screen Component
// ─────────────────────────────────────────────────────────────────────────────

type Props = {
  /** Called with detected tiles + gösterge when user confirms the scan */
  onScanComplete: (result: ScanResult) => void;
  /** Jump to QR scanner to scan a table-join QR code — handled internally */
  onScanQRCode: () => void;
  onGoBack: () => void;
  /** Pre-populated gösterge for gösterge-scan mode */
  gösterge?: GöstergeTile;
};

// ─────────────────────────────────────────────────────────────────────────────
// QR Code Scanner Modal (uses expo-camera — no extra dependency needed)
// ─────────────────────────────────────────────────────────────────────────────

type QRModalProps = {
  visible: boolean;
  onCodeScanned: (tableCode: string) => void;
  onClose: () => void;
};

function QRJoinModal({ visible, onCodeScanned, onClose }: QRModalProps) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);

  const handleBarcode = useCallback((result: { data: string }) => {
    if (scanned) return;
    const raw = result.data; // expected: okey://join/1234
    const match = raw.match(/okey:\/\/join\/(\d{4})/);
    if (match) {
      setScanned(true);
      onCodeScanned(match[1]);
    }
  }, [scanned, onCodeScanned]);

  if (!permission) {
    return (
      <Modal visible={visible} animationType="slide">
        <View style={qrS.centered}><Text style={qrS.white}>Kamera wird geladen…</Text></View>
      </Modal>
    );
  }

  if (!permission.granted) {
    return (
      <Modal visible={visible} animationType="slide">
        <View style={[qrS.centered, qrS.permissionBg]}>
          <Text style={qrS.white}>Kamera-Zugriff benötigt</Text>
          <Text style={qrS.hint}>OkeyScout braucht die Kamera um QR-Codes zu scannen.</Text>
          <TouchableOpacity style={qrS.primaryBtn} onPress={requestPermission}>
            <Text style={qrS.primaryBtnTxt}>Berechtigung erteilen</Text>
          </TouchableOpacity>
          <TouchableOpacity style={qrS.linkBtn} onPress={onClose}>
            <Text style={qrS.linkBtnTxt}>Abbrechen</Text>
          </TouchableOpacity>
        </View>
      </Modal>
    );
  }

  return (
    <Modal visible={visible} animationType="slide">
      <View style={qrS.container}>
        <CameraView
          style={StyleSheet.absoluteFill}
          barcodeScannerSettings={{ barcodeTypes: ['qr'] }}
          onBarcodeScanned={scanned ? undefined : handleBarcode}
        >
          <View style={qrS.overlay}>
            <View style={qrS.topBar}>
              <TouchableOpacity onPress={onClose} style={qrS.closeBtn}>
                <Text style={qrS.closeBtnTxt}>✕</Text>
              </TouchableOpacity>
              <Text style={qrS.title}>QR-Code scannen</Text>
              <View style={{ width: 44 }} />
            </View>

            <View style={qrS.scanArea}>
              <View style={qrS.cornerTL} />
              <View style={qrS.cornerTR} />
              <View style={qrS.cornerBL} />
              <View style={qrS.cornerBR} />
            </View>

            <Text style={qrS.hint}>Scanne den QR-Code vom Tisch-Ersteller</Text>
          </View>
        </CameraView>
      </View>
    </Modal>
  );
}

// QR Modal shared styles
const qrS = StyleSheet.create({
  container:    { flex: 1, backgroundColor: '#000' },
  centered:     { flex: 1, justifyContent: 'center', alignItems: 'center', gap: 16, padding: 32 },
  permissionBg: { backgroundColor: '#0f0f1a' },
  overlay:      { flex: 1, backgroundColor: 'rgba(0,0,0,0.5)' },
  topBar:       { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: 60, paddingHorizontal: 20 },
  closeBtn:     { width: 44, height: 44, justifyContent: 'center', alignItems: 'center' },
  closeBtnTxt:  { color: '#fff', fontSize: 22 },
  title:        { color: '#fff', fontSize: 18, fontWeight: '600' },
  scanArea:     { flex: 1, justifyContent: 'center', alignItems: 'center', marginHorizontal: 60 },
  cornerTL:     { position: 'absolute', top: -2, left: -2, width: 30, height: 30, borderTopWidth: 3, borderLeftWidth: 3, borderColor: '#e94560', borderRadius: 4 },
  cornerTR:     { position: 'absolute', top: -2, right: -2, width: 30, height: 30, borderTopWidth: 3, borderRightWidth: 3, borderColor: '#e94560', borderRadius: 4 },
  cornerBL:     { position: 'absolute', bottom: -2, left: -2, width: 30, height: 30, borderBottomWidth: 3, borderLeftWidth: 3, borderColor: '#e94560', borderRadius: 4 },
  cornerBR:     { position: 'absolute', bottom: -2, right: -2, width: 30, height: 30, borderBottomWidth: 3, borderRightWidth: 3, borderColor: '#e94560', borderRadius: 4 },
  hint:         { color: 'rgba(255,255,255,0.7)', fontSize: 15, textAlign: 'center', paddingBottom: 40 },
  white:        { color: '#fff', fontSize: 18 },
  primaryBtn:   { backgroundColor: '#e94560', paddingHorizontal: 32, paddingVertical: 14, borderRadius: 12 },
  primaryBtnTxt:{ color: '#fff', fontSize: 16, fontWeight: '600' },
  linkBtn:      { padding: 12 },
  linkBtnTxt:   { color: 'rgba(255,255,255,0.5)', fontSize: 14 },
});

const THROTTLE = 400; // ms between inference runs (~2.5 FPS overlay)

export default function CameraScannerScreen({
  onScanComplete, onScanQRCode, onGoBack, gösterge: göstergeProp,
}: Props) {
  const { hasPermission, requestPermission } = useCameraPermission();
  const device = useCameraDevice('back');

  const [isActive,    setIsActive]    = useState(true);
  const [detections,  setDetections]  = useState<DetectedTile[]>([]);
  const [fps,          setFps]         = useState(0);
  const [modelReady,  setModelReady]  = useState(false);
  const [showQRModal, setShowQRModal] = useState(false);

  const lastRun = useRef(0);
  const { plugin, ready } = useOkeyTfliteModel();

  useEffect(() => { setModelReady(ready); }, [ready]);

  // ── JS thread callback ────────────────────────────────────────────────
  // This function is passed via runOnJS from the camera worklet
  const jsCallback = useCallback((
    buf: ArrayBuffer, pw: number, ph: number,
    state: string, modelRef: unknown, fw: number, fh: number,
  ) => {
    const now = Date.now();
    if (now - lastRun.current < THROTTLE) return;
    lastRun.current = now;

    const tiles = runInference(buf, pw, ph, state,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      modelRef as any, fw, fh);
    setDetections(tiles);
    setFps(Math.round(1000 / THROTTLE));
  }, []);

  // ── Frame output (v5 API) ──────────────────────────────────────────────
  const frameOutput = useFrameOutput({
    targetResolution:    { width: 640, height: 480 },
    pixelFormat:         'yuv',
    dropFramesWhileBusy: true,
    onFrame: (frame: Frame) => {
      'worklet';

      const planes = frame.getPlanes();
      if (!planes?.length) return;

      const yPlane  = planes[0];
      const yBuf: ArrayBuffer = yPlane.getPixelBuffer();
      const fw = frame.width, fh = frame.height;

      // Pass to JS thread for inference
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const helper = (globalThis as any).__workletsAsyncHelper;
      if (helper) {
        helper(jsCallback, yBuf, yPlane.width, yPlane.height,
          plugin.state, plugin.model, fw, fh);
      }
    },
  });

  // ── Confirm scan ─────────────────────────────────────────────────────
  const confirmScan = useCallback(() => {
    if (!detections.length) {
      Alert.alert('Keine Tiles erkannt', 'Rack besser ausrichten und erneut scannen.');
      return;
    }
    const tiles: Tile[] = detections.map(d => ({
      color:       d.color ?? 'RED',
      number:      d.number ?? 1,
      isFalseOkey: d.isOkey,
    }));
    onScanComplete({
      tiles,
      gösterge: (göstergeProp as DetectedTile | null) ?? null,
      tableId: null,
    });
  }, [detections, onScanComplete, göstergeProp]);

  // ── Permission ─────────────────────────────────────────────────────────
  useEffect(() => {
    if (!hasPermission) requestPermission();
  }, [hasPermission, requestPermission]);

  // ── States ─────────────────────────────────────────────────────────────
  if (!hasPermission) {
    return (
      <View style={S.centered}>
        <Text style={S.hint}>Kamera-Zugriff wird benötigt.</Text>
        <TouchableOpacity style={S.btn} onPress={requestPermission}>
          <Text style={S.btnText}>Berechtigung erteilen</Text>
        </TouchableOpacity>
        <TouchableOpacity style={[S.btn, S.btnSec]} onPress={onGoBack}>
          <Text style={S.btnText}>Zurück</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={S.centered}>
        <ActivityIndicator size="large" color="#e94560" />
        <Text style={S.hint}>Kamera wird initialisiert…</Text>
      </View>
    );
  }

  const { width: W, height: H } = Dimensions.get('window');

  return (
    <View style={S.container}>
      {/* Camera */}
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={isActive}
        enableNativeZoomGesture
        outputs={[frameOutput]}
      />

      {/* Bounding box overlay */}
      {detections.length > 0 && (
        <View style={StyleSheet.absoluteFill} pointerEvents="none">
          {detections.map((t, i) => (
            <View
              key={i}
              style={[
                S.bbox,
                {
                  left:  t.bbox.x * W,
                  top:   t.bbox.y * H,
                  width: t.bbox.width  * W,
                  height: t.bbox.height * H,
                },
              ]}
            >
              <View style={S.bboxBorder} />
              <View style={S.bboxLabel}>
                <Text style={S.bboxLabelTxt}>
                  {t.isOkey ? '★' : (t.number ?? '?')}
                  {' '}
                  {t.color != null ? t.color[0] : '?'}
                </Text>
                <Text style={S.confTxt}>{Math.round(t.confidence * 100)}%</Text>
              </View>
            </View>
          ))}
        </View>
      )}

      {/* HUD */}
      <View style={S.hud}>
        <View style={S.hudTop}>
          <TouchableOpacity style={S.iconBtn} onPress={onGoBack}>
            <Text style={S.iconBtnTxt}>✕</Text>
          </TouchableOpacity>

          <View style={S.hudBadges}>
            <View style={[S.badge, !modelReady && S.badgeLoading]}>
              <Text style={S.badgeTxt}>
                {modelReady ? '🤖 TFLite' : '⏳ Model…'}
              </Text>
            </View>
            <View style={S.badge}>
              <Text style={S.badgeTxt}>🔍 {fps} FPS</Text>
            </View>
          </View>
        </View>

        <TouchableOpacity style={S.qrScanBtn} onPress={() => setShowQRModal(true)}>
          <Text style={S.qrScanTxt}>📷 QR: Tisch beitreten</Text>
        </TouchableOpacity>

        <View style={S.rackGuide} />

        <Text style={S.hudHint}>Okey-Rack (Istaka) in den Rahmen halten</Text>

        <View style={S.countBadge}>
          <Text style={S.countTxt}>
            {detections.length} Tiles erkannt
          </Text>
        </View>
      </View>

      {/* Controls */}
      <View style={S.controls}>
        <TouchableOpacity
          style={[S.captureBtn, !detections.length && S.captureBtnDis]}
          onPress={confirmScan}
          disabled={!detections.length}
        >
          <View style={S.captureBtnIn} />
        </TouchableOpacity>
      </View>

      {/* QR Join Modal */}
      <QRJoinModal
        visible={showQRModal}
        onCodeScanned={(tableCode) => {
          setShowQRModal(false);
          // Navigate to CreateJoin and auto-join
          onScanQRCode();
        }}
        onClose={() => setShowQRModal(false)}
      />
    </View>
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Styles
// ─────────────────────────────────────────────────────────────────────────────

const S = StyleSheet.create({
  container:  { flex: 1, backgroundColor: '#000' },
  centered:   { flex: 1, backgroundColor: '#000', justifyContent: 'center', alignItems: 'center', gap: 16 },
  hint:       { color: 'rgba(255,255,255,0.62)', fontSize: 16, textAlign: 'center', paddingHorizontal: 32 },

  hud:        { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0 },
  hudTop:     { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-start', paddingTop: 52, paddingHorizontal: 20 },
  iconBtn:    { width: 44, height: 44, borderRadius: 22, backgroundColor: 'rgba(22,33,62,0.72)', justifyContent: 'center', alignItems: 'center' },
  iconBtnTxt: { color: '#fff', fontSize: 18 },
  hudBadges:  { flexDirection: 'row', gap: 8 },
  badge:      { backgroundColor: 'rgba(22,33,62,0.72)', paddingHorizontal: 10, paddingVertical: 5, borderRadius: 16 },
  badgeLoading: { backgroundColor: '#e67e22' },
  badgeTxt:   { color: '#fff', fontSize: 12, fontWeight: '600' },

  qrScanBtn:  { position: 'absolute', top: 52, alignSelf: 'center', backgroundColor: 'rgba(22,33,62,0.72)', paddingHorizontal: 16, paddingVertical: 8, borderRadius: 20 },
  qrScanTxt:  { color: '#fff', fontSize: 13, fontWeight: '600' },

  rackGuide:  { position: 'absolute', top: '28%', left: '8%', right: '8%', height: '22%', borderWidth: 2, borderColor: 'rgba(255,255,255,0.48)', borderRadius: 12 },
  hudHint:    { position: 'absolute', bottom: 190, left: 0, right: 0, textAlign: 'center', color: 'rgba(255,255,255,0.62)', fontSize: 14 },
  countBadge: { position: 'absolute', bottom: 155, alignSelf: 'center', backgroundColor: '#e94560', paddingHorizontal: 16, paddingVertical: 6, borderRadius: 20 },
  countTxt:   { color: '#fff', fontSize: 14, fontWeight: '700' },

  bbox:       { position: 'absolute', borderWidth: 2, borderColor: '#f1c40f', borderRadius: 5, overflow: 'visible' },
  bboxBorder: { flex: 1 },
  bboxLabel:  { position: 'absolute', top: -2, left: -2, backgroundColor: '#f1c40f', paddingHorizontal: 5, paddingVertical: 2, borderRadius: 4, flexDirection: 'row', alignItems: 'center', gap: 4 },
  bboxLabelTxt: { color: '#111', fontSize: 12, fontWeight: '800' },
  confTxt:    { color: '#555', fontSize: 10 },

  controls:   { position: 'absolute', bottom: 50, left: 0, right: 0, alignItems: 'center' },
  captureBtn: { width: 72, height: 72, borderRadius: 36, backgroundColor: '#fff', justifyContent: 'center', alignItems: 'center', borderWidth: 4, borderColor: 'rgba(255,255,255,0.38)' },
  captureBtnDis: { opacity: 0.38 },
  captureBtnIn:  { width: 58, height: 58, borderRadius: 29, backgroundColor: '#fff' },

  btn:        { backgroundColor: '#e94560', paddingHorizontal: 24, paddingVertical: 12, borderRadius: 10 },
  btnSec:     { backgroundColor: 'transparent', borderWidth: 1, borderColor: '#555' },
  btnText:    { color: '#fff', fontSize: 16, fontWeight: '600' },
});
