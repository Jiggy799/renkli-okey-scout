/**
 * OkeyScout — QR Scanner Component (using expo-camera built-in barcode scanning)
 * src/components/QRScannerOverlay.tsx
 */

import { useState, useCallback } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal } from 'react-native';
import { CameraView, useCameraPermissions, BarcodeScanningResult } from 'expo-camera';

type Props = {
  visible: boolean;
  onCodeScanned: (tableCode: string) => void;
  onClose: () => void;
};

export default function QRScannerOverlay({ visible, onCodeScanned, onClose }: Props) {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);

  const handleBarcode = useCallback((result: BarcodeScanningResult) => {
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
        <View style={S.centered}><Text style={S.white}>Kamera-Berechtigung wird geladen…</Text></View>
      </Modal>
    );
  }

  if (!permission.granted) {
    return (
      <Modal visible={visible} animationType="slide">
        <View style={[S.centered, S.permissionBg]}>
          <Text style={S.white}>Kamera-Zugriff benötigt</Text>
          <Text style={S.hint}>OkeyScout braucht die Kamera um QR-Codes zu scannen.</Text>
          <TouchableOpacity style={S.primaryBtn} onPress={requestPermission}>
            <Text style={S.primaryBtnTxt}>Berechtigung erteilen</Text>
          </TouchableOpacity>
          <TouchableOpacity style={S.linkBtn} onPress={onClose}>
            <Text style={S.linkBtnTxt}>Abbrechen</Text>
          </TouchableOpacity>
        </View>
      </Modal>
    );
  }

  return (
    <Modal visible={visible} animationType="slide">
      <View style={S.container}>
        <CameraView
          style={StyleSheet.absoluteFill}
          barcodeScannerSettings={{
            barcodeTypes: ['qr'],
          }}
          onBarcodeScanned={scanned ? undefined : handleBarcode}
        >
          <View style={S.overlay}>
            <View style={S.topBar}>
              <TouchableOpacity onPress={onClose} style={S.closeBtn}>
                <Text style={S.closeBtnTxt}>✕</Text>
              </TouchableOpacity>
              <Text style={S.title}>QR-Code scannen</Text>
              <View style={{ width: 44 }} />
            </View>

            <View style={S.scanArea}>
              <View style={S.cornerTL} />
              <View style={S.cornerTR} />
              <View style={S.cornerBL} />
              <View style={S.cornerBR} />
            </View>

            <Text style={S.hint}>
              Scanne den QR-Code vom Tisch-Ersteller
            </Text>
          </View>
        </CameraView>
      </View>
    </Modal>
  );
}

const S = StyleSheet.create({
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
