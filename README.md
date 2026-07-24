# RenkliOkeyScout

**Dein Okey-Score-Helfer mit AI-Stein-Erkennung**

Eine mobile App (Flutter) zum Zählen und Auswerten von Okey-Spielen. Macht Schluss mit Stift und Papier — die App berechnet automatisch Minuspunkte, Joker-Multiplikatoren, Çifte-Regel und Gösterge-Boni.

---

## 🎴 Okey-Regeln — Quick Reference

### Farbwerte (Tischfarbe = Multiplikator)
| | Farbe | Joker-Regel |
|-|--------|-------------|
| 🟨 | **Gelb ×2** | Gösterge + 1 (13 → 1 wrap) |
| 🟦 | **Blau ×3** | Joker füllt genau EINE Lücke in einer Reihe |
| 🟥 | **Rot ×4** | — |
| ⬛ | **Schwarz ×5** | — |

### Multiplikatoren
| Ereignis | Faktor |
|----------|--------|
| Tischfarbe Gelb | ×2 |
| Tischfarbe Blau | ×3 |
| Tischfarbe Rot | ×4 |
| Tischfarbe Schwarz | ×5 |
| Joker abgelegt (Okey Atmak) | ×2 |
| Çifte-Status + Verlust | ×2 |
| **Maximal** (Schwarz + Joker + Çifte) | ×20 |

### Serien (3+ aufeinanderfolgende Zahlen, gleiche Farbe)
```
✅  Gelb 3 – Gelb 4 – Gelb 5
✅  Rot 12 – Rot 13 – Rot 1        ← Corner-Wrap!
✅  Blau 5 – Blau Joker – Blau 7   ← Joker füllt 1 Lücke
❌  Rot 13 – Rot 1 – Rot 2         ← 13→1→2 verboten!
```

### Joker-Regel
- Joker (Okey) = Gösterge + 1
- Joker füllt **genau EINE** Lücke in einer Reihe
- Zwei Joker in einer Reihe ❌
- Sahte Okey (Stern) = Joker-Ersatz
- ⚠️ **Kleeblatt/Sahte Okey ist in der App NICHT auswählbar** (visuelle Joker-Markierung, nicht als Gösterge oder Joker wählbar)

### Çifte (Paare) — Zwei gültige Varianten
```
Variante 1:  7 Doppelpaare              → 0 Minuspunkte ✅
             (7 Paare = alle 14 Steine)

Variante 2:  5 Paare + 1 Reihe aus 4    → Joker erlaubt ✅
             (5 Paare + 4 Steine = 14)
```

### Gösterge-Regel (System B)

**Wichtig:** Der Gösterge kann **ausschließlich direkt nach dem Austeilen** gezeigt werden (bevor der Halter seinen ersten Zug macht). Danach verfällt das Recht für diese Runde.

| Farbe | Belohnung (Farbwert × 10) |
|-------|---------------------------|
| Gelb | −20 |
| Blau | −30 |
| Rot | −40 |
| Schwarz | −50 |

**Variante A — Straf-Variante:** Halter zeigt → andere **+Farbwert×10**, Halter 0.
**Variante B — Belohnungs-Variante:** Halter zeigt → Halter **−Farbwert×10**, andere 0.

**Endabrechnung (nach 11 Runden):**
```
Gesamt = Σ SystemA − Σ SystemB
```
→ Spieler kann mit **negativen Punkten** ins Ziel kommen (Gewinner 🏆)!

### Corner-Regel
```
✅ 12 → 13 → 1         (Wrap erlaubt)
❌ 13 → 1 → 2         (1 ist absoluter Stopp)
```

### Foto-Pflicht
Kein Foto der eigenen Steine am Rundenende = **+100 Strafpunkte**

---

## Was die App kann

### 🎯 Scoring
- **Tischfarbe wählen**: Gelb (×2), Blau (×3), Rot (×4), Schwarz (×5)
- **Joker-Multiplikator**: Okey ablegen = ×2 auf die Runde
- **Çifte-Status**: Spieler der "Çifte Gitmek" nimmt, hat ×2 Penalty bei Verlust
- **Gösterge-Regel**: Wer die offene Gösterge-Karte zeigt, verteilt Minuspunkte an alle anderen
- **Corner-Regel**: 12 → 13 → 1 ist erlaubt; 13 → 1 → 2 ist verboten
- **Foto-Pflicht**: Kein Foto der Steine = +100 Strafpunkte

### 🧠 AI-Stein-Erkennung
- **ONNX YOLO Modell** für Bounding-Box-Erkennung von Steinen auf dem Tisch
- **Farb-Klassifikator** für Gelb / Blau / Rot / Schwarz
- **Zwei Modi**: ONNX direkt auf dem Gerät oder M90q als Vision-Proxy über LAN
- **Fallback**: Manuelle Eingabe wenn AI nicht verfügbar

### 👥 Spielmodi
- **Demo-Modus**: 1-Spieler oder 2-Spieler (ohne Backend, alles lokal)
- **Online-Modus**: Supabase Realtime — Tisch erstellen, QR-Code teilen, mit Freunden spielen

---

## Tech-Stack

| Bereich | Technologie |
|---------|-----------|
| App | Flutter / Dart |
| Backend | Supabase (PostgreSQL + Realtime + Storage) |
| Auth | Supabase Anonymous Sign-ins |
| AI (lokal) | ONNX Runtime (`onnxruntime` ^1.4.1) |
| AI (remote) | M90q Ollama über LAN (`http://192.168.178.187:11434`) |
| Kamera | `mobile_scanner` (QR-Codes + Bildaufnahme) |
| Bilderkennung | Custom YOLO ONNX Modell |

---

## Projektstruktur

```
lib/
├── main.dart                    # App-Entry-Point
├── app.dart                     # Supabase-Init + Theming
├── router.dart                  # GoRouter Navigation
├── models/
│   ├── tile.dart                # Tile (color, number, isOkey, isSahte)
│   ├── player.dart              # Spieler mit Punkten
│   └── round.dart               # Runde mit Steinen + Scores
├── screens/
│   ├── home_screen.dart         # Startbildschirm
│   ├── rules_screen.dart        # Vollständiges Regelwerk
│   ├── demo_setup_screen.dart   # Demo: Spieleranzahl wählen
│   ├── demo_active_round_screen.dart  # Demo-Runde
│   ├── demo_round_result_screen.dart  # Demo-Ergebnis
│   ├── active_round_screen.dart # Online-Runde
│   ├── round_result_screen.dart # Online-Ergebnis
│   └── camera_result_screen.dart # Foto-Resultat
├── services/
│   ├── supabase_service.dart    # Supabase Client + alle Queries
│   ├── score_calculator.dart    # Engine: Joker, Corner, Çifte, Strafpunkte
│   ├── vision_service.dart      # ONNX → M90q-Proxy → Manual
│   ├── tile_detector.dart       # YOLO Bounding-Box Detector
│   └── tile_classifier.dart     # Farb-Klassifikator
└── widgets/
    ├── tile_widget.dart         # Einzelner Stein (visuell)
    └── player_card.dart         # Spieler-Karte mit Score

assets/
└── models/
    └── okey_yolo_best.onnx     # YOLO Bounding-Box Modell (12 MB)
```

---

## Setup & Installation

### Voraussetzungen
- Flutter SDK 3.12+
- Android SDK 33+ (für ONNX Runtime)
- Supabase Projekt (Projekt-ID: `ntssssvyyptvdjerbtll`)

### Android build
```bash
flutter pub get
flutter build apk --debug
```

### APK installieren
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Supabase Schema

| Tabelle | Beschreibung |
|---------|-------------|
| `profiles` | Spieler (UUID, Name, Avatar-URL, Joker-Bonus) |
| `tables` | Spieltische (Code, Ersteller, Spieler-Liste, Status) |
| `rounds` | Runden (Tisch-ID, Gösterge-Farbe/Zahl, Joker-Finish, Foto-URL) |
| `round_players` | Runden-Spieler (Runde, Spieler, Çifte-Status, Strafpunkte) |

**RPC-Funktionen:**
- `increment_gosterge_count(uuid)` — Gösterge-Zähler erhöhen

---

## APK Downloads

| Version | Datei | Datum |
|---------|-------|-------|
| v1.3.1 | `RenkliOkeyScout-v6-debug.apk` | Juli 2026 |
| v1.3.0 | `RenkliOkeyScout-v8-debug.apk` | Juli 2026 |
| v1.2.1 | `RenkliOkeyScout-v7-debug.apk` | Juli 2026 |
| v1.2.0 | `RenkliOkeyScout-v6-debug.apk` | Juli 2026 |

Alle Releases: [github.com/Jiggy799/renkli-okey-scout/releases](https://github.com/Jiggy799/renkli-okey-scout/releases)

---

## Offene Tasks

- [ ] ONNX Runtime android-36 Support abwarten → dann Detector aktivieren
- [ ] M90q Vision-Proxy (Ollama) als Fallback für Tile-Erkennung
- [ ] Collect-Screen mit Auto-Label-UI für Training-Daten
- [ ] Multiplayer zwischen zwei Handys testen
- [ ] App-Icon (mipmap) durch echte Grafik ersetzen
- [ ] Play Store Veröffentlichung
