# OkeyScout

Mobiler Okey-Scanner mit Kamera-Tile-Erkennung und Multiplayer-Lobby.

## Features

- **Tile-Scanner** — Kamera-basierte Erkennung der 15 Okey-Kacheln (TFLite-Modell + react-native-vision-camera v5)
- **QR-Tisch-Beitritt** — QR-Code scannen um einem Tisch beizutreten (`okey://join/<CODE>` Deep Link)
- **Score-Berechnung** — Vollständige Okey-Regel-Engine: Serien, Gruppen, Paare, alle Multiplikatoren (Renkli ×2, Okey atmak ×2, Çifte bitmek ×2, False-Finish −4/−8)
- **Verlierer-Strafen** — Automatische Strafen-Berechnung pro Verlierer mit Multiplikator-Anzeige
- **Multiplayer-Lobby** — Supabase Realtime: 4 Spieler, Gösterge-Auswahl, Runde-Start

## Tech Stack

| Ebene | Technologie |
|-------|------------|
| Frontend | React Native (Expo, New Architecture) |
| Kamera-Pipeline | react-native-vision-camera v5 (Frame Output API) |
| KI-Inferenz | react-native-fast-tflite |
| Backend/Datenbank | Supabase (PostgreSQL + Realtime + Anonymous Auth) |
| Auth | Supabase Anonymous Sign-In (schneller Beitritt ohne Konto) |

## Setup

### 1. Abhängigkeiten installieren

```bash
cd OkeyScout
npm install
```

### 2. Supabase-Projekt einrichten

1. [Supabase Dashboard](https://supabase.com/dashboard) → Neues Projekt erstellen
2. **Database Schema** — SQL-Migration ausführen:
   - Im Supabase Dashboard: SQL Editor → `supabase/migrations/001_initial.sql` einfügen und ausführen
   - Oder lokal: `supabase db push` (mit installierter Supabase CLI)
3. **Anonymous Sign-In** aktivieren:
   - Dashboard → Authentication → Providers → Anonymous Sign-ins → **aktivieren**
4. **API Keys** kopieren:
   - Dashboard → Settings → API → `SUPABASE_URL` und `SUPABASE_ANON_KEY`

### 3. Umgebungsvariablen

```bash
cp .env.example .env
# .env ausfüllen:
EXPO_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
```

### 4. TFLite-Modell

Das Tile-Erkennungsmodell (`.tflite`) muss nach `assets/models/okey_tiles.tflite` kopiert werden. Zum Trainieren eines Modells:

```bash
# 1. Sammle Trainingsbilder (Rack-Fotos)
# 2. Annotiere mit LabelImg oder CVAT
# 3. Konvertiere zu TFLite mit TensorFlow Lite Converter
```

> **Platzhalter**: Bis das Modell verfügbar ist, funktioniert der Scanner als Demo mit zufälligen Tile-Detections.

### 5. App starten

```bash
npx expo start
```

## Supabase Schema (Überblick)

```
tables          — 4-stelliger Tisch-Code, Status (lobby/playing/finished)
table_players   — Spieler-Zuordnung zu Tischen (max 4)
rounds          — Runde pro Tisch (Gösterge, Gewinner, Status)
round_hands     — Gescannte Kacheln pro Spieler/Runde (nur own lesbar)
profiles        — auth.users Erweiterung (username, avatar)
```

## Okey-Regel-Engine

Alle Regeln in `src/utils/okeyEngine.ts`:

- **Gösterge → Okey** — Ausgeschlossene Farbe + gleiche Zahl
- **Serien** — 3–5 aufeinanderfolgende gleiche Farbe
- **Gruppen** — 3 gleiche Zahlen in verschiedenen Farben
- **Paare** — 2 gleitende Joker (7 Paare = "Çifte")
- **Wildcards** — Gösterge + alle False Okeys
- **Multiplikatoren**: Renkli ×2, Okey atmak ×2, Çifte bitmek ×2
- **False-Finish**: −4 (ungeprüft), −8 (nach Gewinn ≠ gültige Hand)

## Deep Links

```
okey://join/<CODE>   — Tisch beitreten
```

## Ordnerstruktur

```
src/
├── components/
│   └── QRScannerOverlay.tsx   # QR-Scanner Modal (expo-camera)
├── screens/
│   ├── CameraScannerScreen.tsx  # Rack-Scanner + TFLite-Pipeline
│   ├── CreateJoinTableScreen.tsx
│   ├── GameScreen.tsx
│   ├── LobbyScreen.tsx
│   └── ScoreScreen.tsx
├── services/
│   └── supabase.ts   # Client + Realtime-Subscriptions
└── utils/
    └── okeyEngine.ts  # Regel-Engine
```
