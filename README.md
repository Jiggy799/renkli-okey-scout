# RenkliOkeyScout

**🎴 Deine Okey-Score-Begleit-App — Schluss mit Stift und Papier!**

Eine Flutter-App für Android die Okey-Punkte automatisch berechnet: Gösterge, Joker, Çifte, Foto-Pflicht. Funktioniert **komplett offline** mit Anonymous-Login oder mit echter Google-Anmeldung. Multiplayer über Supabase mit QR-Code-Beitritt.

📥 **Download v1.6.2:** https://github.com/Jiggy799/renkli-okey-scout/releases/tag/v1.6.2

---

## 🎴 Okey-Regeln — Quick Reference

### Farbwerte (Tischfarbe = Multiplikator)

| | Farbe | Joker-Regel |
|---|-------|-------------|
| 🟨 | **Gelb ×2** | Gösterge + 1 (13 → 1 wrap) |
| 🟦 | **Blau ×3** | Joker füllt genau EINE Lücke in einer Reihe |
| 🟥 | **Rot ×4** | — |
| ⬛ | **Schwarz ×5** | — |

### Multiplikatoren-Matrix

| Ereignis | Faktor |
|----------|--------|
| Tischfarbe Gelb | ×2 |
| Tischfarbe Blau | ×3 |
| Tischfarbe Rot | ×4 |
| Tischfarbe Schwarz | ×5 |
| Joker abgelegt (Okey Atmak) | ×2 |
| Çifte-Status + Verlust | ×2 |
| Joker + Çifte kombiniert | ×4 |
| **Maximal** (Schwarz + Joker + Çifte) | ×20 |

### Serien-Beispiele

```
✅  Gelb 3 – Gelb 4 – Gelb 5              ← 3er-Reihe
✅  Gelb 3 – Gelb 4 – Gelb 5 – Gelb 6    ← 4er-Reihe
✅  Rot 12 – Rot 13 – Rot 1               ← Corner-Wrap
✅  Rot 10 – Rot 11 – Rot 12 – Rot 1      ← 4er Corner-Wrap
✅  Blau 5 – Blau Joker – Blau 7          ← Joker füllt 1 Lücke
✅  Rot 5 – Rot 6 – Rot Joker – Rot 8     ← 4 Steine mit Joker
❌  Rot 13 – Rot 1 – Rot 2                ← 13→1→2 verboten!
```

### Joker-Regeln

- Joker (Okey) = Gösterge + 1 (13 → 1 wrap)
- Joker füllt **genau EINE** Lücke in einer Reihe
- Zwei Joker in einer Reihe ❌
- Sahte Okey (Stern ⭐ oder Kleeblatt 🍀) = Joker-Ersatz
- ⚠️ **Kleeblatt/Sahte Okey ist in der App NICHT auswählbar** (visuelle Joker-Markierung)

### Çifte (Paare) — Zwei gültige Varianten

```
Variante 1:  7 Doppelpaare              → 0 Minuspunkte ✅
             (7 Paare = alle 14 Steine)

Variante 2:  5 Paare + 1 Reihe aus 4    → Joker erlaubt ✅
             (5 Paare + 4 Steine = 14)
             Joker darf in der 4er-Reihe eingesetzt werden
             Joker darf auch ein Paar ersetzen
```

### Gösterge-Regel (System B)

**Wichtig:** Der Gösterge kann **ausschließlich direkt nach dem Austeilen** gezeigt werden (bevor der Halter seinen ersten Zug macht). Danach verfällt das Recht.

| Farbe | Bonus (Halter bekommt) |
|-------|------------------------|
| Gelb | −20 |
| Blau | −30 |
| Rot | −40 |
| Schwarz | −50 |

**Endabrechnung:** `Gesamt = ΣSystemA − ΣGöstergeBonus` — Spieler kann mit **negativen Punkten** ins Ziel kommen (Gewinner 🏆).

### Corner-Regel

```
✅ 11 → 12 → 13 → 1   (Wrap erlaubt — lange Reihe)
✅ 12 → 13 → 1         (Wrap erlaubt — kurze Reihe)
❌ 13 → 1 → 2         (1 ist absoluter Stopp)
```

### Foto-Pflicht

Kein Foto der eigenen Steine am Rundenende = **+100 Strafpunkte**

---

## 🎯 Features

### 🎯 Scoring-Engine
- ✅ **Tischfarbe wählen**: Gelb (×2), Blau (×3), Rot (×4), Schwarz (×5)
- ✅ **Joker-Multiplikator**: Okey ablegen = ×2
- ✅ **Çifte-Status**: ×2 bei Verlust
- ✅ **Gösterge 2-Spieler-Confirm + Lock**: Gösterge muss von 2 Spielern bestätigt werden, dann fixiert
- ✅ **Corner-Regel**: 11→12→13→1 erlaubt
- ✅ **Foto-Pflicht**: +100 wenn vergessen

### 🤖 Authentifizierung
- ✅ **Anonymous Login** (Primary — funktioniert sofort)
- ✅ **Google Sign-In** (UI da, OAuth Client ID konfigurierbar)
- ⏸ **Apple Sign-In** (TODO)

### 📸 Foto-Feature
- ✅ **Echte Kamera** via `image_picker`
- ✅ **Upload zu Supabase Storage** (`round-photos` Bucket)
- ✅ **Permission-Check** vor Kamera

### 👥 Spielmodi
- ✅ **Demo-Modus**: 1-Spieler oder 2-Spieler (lokal, kein Backend)
- ✅ **Online-Modus**: Supabase Realtime, QR-Code, 4 Spieler

### 🔒 Sicherheit
- ✅ **Supabase Auth**: Anonymous + Google
- ✅ **RLS Policies** auf allen Tabellen
- ✅ **Storage Policies** mit Owner-Check
- ✅ **DB-Constraints**: UNIQUE, CHECK 2-12 Zeichen, NOT NULL

---

## 🚀 Quick Start

### Installation auf Android-Handy

**Option A: Direkt von GitHub**
1. Öffne https://github.com/Jiggy799/renkli-okey-scout/releases/tag/v1.6.2 auf dem Handy
2. Tippe auf `app-debug.apk`
3. Erlaube "Installation aus unbekannten Quellen"
4. Installiere + Öffnen

**Option B: Per ADB**
```bash
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Erste Schritte in der App

```
┌─────────────────────────────────────────────┐
│  🀴 RenkliOkeyScout                          │
│                                              │
│  ┌───────────────────────────────────────┐  │
│  │  ▶ ANONYM SPIELEN (sofort loslegen)   │  │  ← Großer grüner Button
│  └───────────────────────────────────────┘  │
│                                              │
│  ┌───────────────────────────────────────┐  │
│  │  Mit Google anmelden                   │  │
│  └───────────────────────────────────────┘  │
│                                              │
│  ┌───────────────────────────────────────┐  │
│  │  Anonym spielen (Demo)                │  │  ← Auch Demo starten
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
       ↓
   [Anonym spielen]
       ↓
   ┌────────────────────────────────────────┐
   │  Home-Screen:                          │
   │  [Online spielen]  → Multiplayer      │
   │  [Demo-Modus]     → 1 oder 2 Spieler  │
   │  [Regelwerk]       → Alle Regeln      │
   └────────────────────────────────────────┘
```

### Demo-Runde spielen

1. **Demo-Modus** tippen
2. **1 Spieler** auswählen (oder 2)
3. **Gösterge definieren**: Farbe + Nummer wählen
4. **2 Spieler bestätigen** den Gösterge (Dropdown)
5. **Runde starten** (Button wird aktiv wenn locked)
6. **Strafpunkte** für Verlierer eingeben
7. **Foto machen** (Kamera geht auf)
8. Nächste Runde oder Game Over

---

## 🧪 Test-Plan

### 5-Minuten-Schnelltest (Solo)

| Schritt | Aktion | Erwartet |
|---------|--------|----------|
| 1 | App öffnen | Login-Screen |
| 2 | "Anonym spielen" | Home-Screen |
| 3 | "Demo-Modus" → "1 Spieler" | Demo-Lobby |
| 4 | Gösterge = Schwarz, Nr 7 | Setup-Screen |
| 5 | 2× bestätigen via Dropdown | "Runde starten" wird aktiv |
| 6 | Runde starten | Aktive Runde |
| 7 | Foto tippen | Kamera öffnet |
| 8 | Foto machen | Upload-OK + ✓ |
| 9 | Strafpunkte = 12 eintragen | Live-Faktor ×5 |
| 10 | Nächste Runde | Rounds-Counter steigt |
| 11 | Nach 11 Runden | Game Over Screen |

### 10-Minuten-Online-Test (2 Handys)

**Setup:**
- Beide Handys im gleichen WLAN
- Einer erstellt Tisch, scannt QR-Code auf dem anderen

**Flow:**
1. Beide öffnen App → "Anonym spielen"
2. Host: "Online spielen" → "Tisch erstellen" → zeigt QR-Code
3. Guest: "Online spielen" → QR-Code scannen → tritt bei
4. Host startet Spiel → beide sehen Tisch
5. Beide spielen → synchronisieren via Realtime
6. Foto hochladen
7. Runden-Ergebnisse synchron

---

## 🛠 Tech-Stack

| Bereich | Technologie |
|---------|-----------|
| App | Flutter 3.12+ / Dart |
| State | Provider |
| Navigation | GoRouter |
| Backend | Supabase (PostgreSQL + Realtime + Storage) |
| Auth | Supabase Anonymous + Google Sign-In |
| Kamera | `image_picker` |
| QR-Code | `mobile_scanner` + `qr_flutter` |
| Bilderkennung | Custom ONNX YOLO Modell (Stub) |
| Local DB | `path_provider` |

---

## 📁 Projektstruktur

```
lib/
├── main.dart                            # App-Entry + Supabase-Init
├── router.dart                          # GoRouter (Redirect-Logik)
├── screens/
│   ├── login_screen.dart                 # Anonymous + Google + Apple-Placeholder
│   ├── nickname_screen.dart              # Nickname-Auswahl (für Google-User)
│   ├── profile_screen.dart               # Nickname editieren
│   ├── home_screen.dart                  # User-Info + Modus-Auswahl
│   ├── lobby_screen.dart                 # Online-Modus: Tisch erstellen/Qr-Scannen
│   ├── demo_lobby_screen.dart            # 1 oder 2 Spieler wählen
│   ├── demo_round_setup_screen.dart      # Gösterge definieren + 2-Spieler-Confirm
│   ├── demo_active_round_screen.dart     # Demo-Runde + Foto-Pflicht
│   ├── demo_round_result_screen.dart     # Demo-Ergebnis
│   ├── demo_game_over_screen.dart        # Demo: Ende nach 11 Runden
│   ├── active_round_screen.dart          # Online-Runde
│   ├── round_result_screen.dart          # Online-Ergebnis
│   ├── game_over_screen.dart             # Online-Ende
│   ├── gosterge_screen.dart              # Gösterge-Setup (Online)
│   ├── rules_screen.dart                 # Animierte Regelwerk-Slides (10 Slides)
│   ├── settings_screen.dart              # Einstellungen
│   └── collect_screen.dart               # Training-Daten sammeln (Beta)
├── services/
│   ├── auth_service.dart                 # Google + Anonymous Auth
│   ├── vision_service.dart               # ONNX on-device (Stub)
│   ├── tile_detector.dart                # YOLO Stub
│   ├── tile_detector_impl.dart           # ONNX (auskommentiert, warten auf android-36)
│   ├── tile_classifier.dart              # Heuristik
│   └── collect_service.dart              # Training-Data Upload
├── utils/
│   └── score_calculator.dart             # Engine (WinType, Gösterge, Joker, Çifte, Corner)
├── demo/
│   └── demo_state.dart                   # Demo-Singleton (Ceyhan, Tugrul, Hakan, Ömer)
└── models/
    └── (im utils/)

assets/
└── models/
    └── okey_yolo_best.onnx               # 12 MB YOLO Modell

supabase/
└── migrations/
    ├── 002_add_game_fields.sql
    ├── 003_rounds_win_type.sql           # joker_finish → win_type enum
    ├── 004_profile_username_unique.sql   # username UNIQUE
    ├── 005_profile_username_validation.sql # CHECK 2-12, NOT NULL
    └── 006_gosterge_confirmed_by.sql     # rounds.gosterge_confirmed_by jsonb
```

---

## 🗄️ Supabase-Schema

### Tabellen

| Tabelle | Beschreibung |
|---------|-------------|
| `profiles` | Spieler (UUID, username 2-12, avatar_url, created_at) |
| `tables` | Spieltische (4-digit Code, status, current_round) |
| `table_players` | Spieler pro Tisch (seat_index, is_cifte, is_ready) |
| `rounds` | Runden (gösterge_tile, win_type, gosterge_confirmed_by) |
| `training_samples` | Trainings-Daten für ONNX-Modell |

### Constraints

| Constraint | Typ |
|------------|-----|
| `profiles_username_unique` | UNIQUE |
| `profiles_username_length` | CHECK (2-12 Zeichen) |
| `rounds_win_type` | CHECK (normal/okey/cifte/okeyCifte) |
| `rounds_gosterge_confirmers_max` | CHECK (≤4 Confirmers) |

### Storage Buckets

| Bucket | Public | Max Size | Purpose |
|--------|--------|----------|---------|
| `round-photos` | ✅ | 10 MB | Runde-Fotos |
| `training-data` | ✅ | 20 MB | ONNX Trainings-Daten |

---

## 🚧 Bekannte Einschränkungen

- **APK-Größe**: 174 MB (Debug-Build, Production ~30 MB)
- **ONNX Runtime**: Stub-Modus aktiv (warten auf android-36 Support)
- **Google Sign-In**: Braucht OAuth Client ID + SHA-1 Setup in Google Cloud Console
- **Apple Sign-In**: TODO

---

## 📜 Versionsverlauf

| Version | Datum | Highlights |
|---------|-------|------------|
| **v1.6.2** | Jul 2026 | Production-Ready: DB-Migration 006, Storage-Owner-Check, ImagePicker-Permission |
| v1.6.1 | Jul 2026 | Gösterge 2-Spieler-Confirm + Lock |
| v1.6.0 | Jul 2026 | Mahjong-Emoji → OKEY-Text-Logo |
| v1.5.5 | Jul 2026 | Foto-Upload zu Supabase Storage |
| v1.5.4 | Jul 2026 | Demo Foto: echte Kamera |
| v1.5.3 | Jul 2026 | Lobby-Screen Cleanup |
| v1.5.2 | Jul 2026 | Anonymous Login als Primary |
| v1.5.1 | Jul 2026 | Nickname-Screen mit Profilen |
| v1.5.0 | Jul 2026 | Google Sign-In + Login-Screen |
| v1.4.0 | Jul 2026 | On-Device Vision (autonom) |
| v1.3.2 | Jul 2026 | M90q Vision-Proxy entfernt + Corner 11-12-13-1 |
| v1.3.1 | Jul 2026 | Joker-Wildcard + 7 Doppel-Paare |

Alle Releases: [github.com/Jiggy799/renkli-okey-scout/releases](https://github.com/Jiggy799/renkli-okey-scout/releases)

---

## 📜 Lizenz

MIT License — Free to use, modify, distribute.

**Maintainer:** Jiggy (Ceyhan) • Frankfurt am Main, Germany

---

🎴 **Bereit zum Spielen!** Starte mit "Anonym spielen" und probiere den Demo-Modus aus.