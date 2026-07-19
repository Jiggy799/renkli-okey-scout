# RenkliOkeyScout — Test-Anleitung

## APK übertragen & installieren

APK liegt unter:
```
/home/jiggy/renkli_okey_scout/build/app/outputs/flutter-apk/app-debug.apk
```

Auf Android-Gerät übertragen (ADB, LAN, AirDrop, etc.):
```bash
adb install -r /home/jiggy/renkli_okey_scout/build/app/outputs/flutter-apk/app-debug.apk
```

Oder: QR-Code im LAN via Python-Server:
```bash
cd /home/jiggy/renkli_okey_scout/build/app/outputs/flutter-apk
python3 -m http.server 8080
# QR zeigt auf: http://<DEINE_IP>:8080/app-debug.apk
```

---

## Voraussetzungen

- [ ] Supabase-Projekt läuft (Schema bereits in Cloud)
- [ ] Anonym-Auth in Supabase aktiviert: Authentication → Providers → Anonymous Sign-ins → **ON**
- [ ] Realtime in Supabase aktiviert: Database → Replication → Tables `tables`, `table_players`, `rounds` → **ON**
- [ ] Supabase URL + Anon-Key in `lib/main.dart` aktuell

---

## Test-Ablauf (2 Handys / 1 Emulator + 1 Handy)

### 1. App starten
- App öffnen → Username eingeben (z.B. "Ceyhan") → "Starten"
- Kein Login nötig (Anonymous Auth)

### 2. Tisch erstellen (Spieler 1)
- "Tisch erstellen" → 4-stelliger Code wird angezeigt
- QR-Code anzeigen für Spieler 2

### 3. Tisch beitreten (Spieler 2)
- "Tisch beitreten" → Kamera öffnet sich → QR-Code scannen
- Oder: 4-stelligen Code manuell eingeben

### 4. Lobby
- Beide Spieler erscheinen in der Lobby
- Host sieht "Bereit" bei sich selbst → Spieler 2 kann nicht für Host toggeln
- Spieler 2: "Bereit" toggeln
- Host: "Spiel starten" Button wird grün

### 5. Gösterge wählen (neu in dieser Version!)
- Nach Start: **Gösterge-Screen** erscheint
- Tisch-Host wählt die offen liegende Karte (Farbe + Zahl)
- "Weiter" → ActiveRoundScreen

### 6. ActiveRoundScreen
- Roter "Tischfarbe"-Header: aktuelle Tischfarbe ×Faktor
- Spieler-Liste mit Strafpunkten
- Aktionen pro Spieler:
  - **Çifte** → toggle (×2 eigene Strafen)
  - **Gösterme** → +30/60/90/120 für alle anderen (einmal pro Runde)
  - **+1 / +5** → Strafpunkte direkt eintragen
- Gelbe Flagge (oben rechts) → "Runde beenden" → RoundResultScreen

### 7. Runde beenden (RoundResultScreen)
- Gewinner auswählen (wer "Okey" gemacht hat)
- Verlierer geben Minuspunkte ein:
  - Echte Minuspunkte = Karten auf der Hand die kein Paar/Serie bilden
  - Faktor = Farbfaktor × Joker × Çifte
- "Ergebnis eintragen" → Spielerpenalten in DB

### 8. Nächste Runde oder Spielende
- **Weitere Runde**: Tisch wird zurückgesetzt, neue Gösterge wählen
- **Spiel beenden**: GameOverScreen mit Endbilanz

---

## Bekannte Einschränkungen

| Feature | Status |
|---------|--------|
| TFLite Steine-Erkennung | Mock (noch kein Modell) |
| Ollama-Vision (M90q) | HTTP-Proxy vorbereitet, aber nicht aktiv |
| Tisch schließen (Ende) | GameOverScreen vorhanden |
| Çifte / Gösterme | Funktioniert in ActiveRoundScreen |
| Realtime-Sync | Funktioniert über Supabase Realtime |
| Deep Link `okeyscout://` | Intent in AndroidManifest.xml |

---

## Farben & Faktoren

| Farbe | Faktor |
|-------|--------|
| Gelb  | ×2     |
| Blau  | ×3     |
| Rot   | ×4     |
| Schwarz | ×5   |

**Strafpunkte-Beispiel**: Rote 8 auf Tisch (×4), Joker-Finish (×2), Çifte (×2)
→ Echte Minuspunkte = 8 × 4 × 2 × 2 = **128 Punkte**

---

## API-Authentifizierung

Supabase Anonymous Sign-in funktioniert automatisch. Kein Email/Passwort nötig.
RLS sorgt dafür dass nur Spieler an einem Tisch deren Daten sehen können.
