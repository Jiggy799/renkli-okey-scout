# RenkliOkeyScout

**Dein Okey-Score-Helfer mit AI-Stein-Erkennung**

Eine mobile App (Flutter) zum Zählen und Auswerten von Okey-Spielen. Macht Schluss mit Stift und Papier — die App berechnet automatisch Minuspunkte, Joker-Multiplikatoren, Çifte-Regel und Gösterge-Boni.

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

## Okey-Regeln (Kurzübersicht)

### Farbwerte (Tischfarbe = Multiplikator)
| Farbe | Multiplikator | Joker-Regel |
|-------|--------------|-------------|
| Gelb | ×2 | Gösterge + 1 (13 → 1 wrap) |
| Blau | ×3 | Joker füllt genau EINE Lücke in einer Reihe |
| Rot | ×4 | |
| Schwarz | ×5 | |

### Serien
- 3+ aufeinanderfolgende Zahlen **derselben Farbe**
- 12 → 13 → 1 ✓ (Wrap erlaubt)
- 13 → 1 → 2 ✗ (1 ist absoluter Stopp)

### Joker in Reihen
- Ein Joker (Okey) darf **genau eine** Lücke in einer Reihe füllen
- Zwei Joker in einer Reihe ✗

### Gruppen
- Mindestens 3 Steine mit **derselben Zahl**, unterschiedlichen Farben

### Çifte (Paare)
Zwei gültige Varianten:
1. **7 Doppelpaare** (alle 14 Steine = 7 Paare) → 0 Minuspunkte
2. **5 Paare + 1 Reihe aus 4 Steinen** (alle 14 Steine) → Joker erlaubt

### Strafpunkte (System A)
```
Runde_Punkte = Schrott_Steine × Tischfarbe × Joker × Çifte
```

### Gösterge-Regel (System B)
Gösterge zeigt die offene Karte → Alle anderen bekommen Minuspunkte:
- Gelb: −20 | Blau: −30 | Rot: −40 | Schwarz: −50
- Gesammelt über 11 Runden, am Ende abgezogen

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
