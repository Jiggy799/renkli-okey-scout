# 🔐 Google OAuth Web Client ID — Setup-Anleitung

## Was du brauchst

- ✅ Google Cloud Console Account
- ✅ 5 Minuten Zeit
- ✅ Supabase PAT (haben wir)

## Schritt-für-Schritt

### 1. Google Cloud Console öffnen
https://console.cloud.google.com/apis/credentials

### 2. Projekt erstellen oder wählen
- Falls Popup kommt: **Neues Projekt** → Name: `RenkliOkeyScout`
- Falls nicht: oben links **Projekt-Dropdown** → dein Projekt

### 3. OAuth Consent Screen (nur beim ersten Mal)
- Falls Popup kommt: **OAuth-Zustimmungsbildschirm konfigurieren**
- User-Typ: **Extern**
- App-Name: `RenkliOkeyScout`
- Support-Email: `ceyhan.aydemir@gmail.com`
- **Speichern**

### 4. OAuth Client ID erstellen
- **Anmeldedaten erstellen** → **OAuth-Client-ID**

**WICHTIG — Application Type:**
- ✅ **Webanwendung** (NICHT Android!)
- Name: `RenkliOkeyScout Web Client`

**Authorized JavaScript origins:**
```
https://ntssssvyyptvdjerbtll.supabase.co
```

**Authorized redirect URIs:**
```
https://ntssssvyyptvdjerbtll.supabase.co/auth/v1/callback
```

→ **Erstellen**

### 5. Du bekommst

```
Client-ID:     123456789-abc...xyz.apps.googleusercontent.com
Client-Secret: GOCSPX-AbC...XyZ
```

⚠️ **Beide Werte sicher kopieren!**

---

## Was ich damit mache

### A. App neu bauen

```bash
cd /home/jiggy/renkli_okey_scout
flutter build apk --debug \
  --dart-define=GOOGLE_WEB_CLIENT_ID=DEINE_CLIENT_ID \
  --dart-define=GOOGLE_WEB_CLIENT_SECRET=DEIN_SECRET
```

### B. Supabase Google Provider aktivieren

```bash
PAT="sbp_v0_ae711db353fec079e2f480a7465f4862596afcb5"
curl -X PATCH \
  "https://api.supabase.com/v1/projects/ntssssvyyptvdjerbtll/config/auth" \
  -H "Authorization: Bearer $PAT" \
  -H "Content-Type: application/json" \
  -d "{
    \"external_google_enabled\": true,
    \"external_google_client_id\": \"DEINE_CLIENT_ID\",
    \"external_google_secret\": \"DEIN_SECRET\"
  }"
```

### C. Login-Screen nutzt dann deinen echten Key

```dart
// google_auth_config.dart
class GoogleAuthConfig {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: 'PLACEHOLDER',  // wird überschrieben
  );
}
```

---

## ⚠️ Wichtige Hinweise

1. **HTTPS only** — `accounts.google.com` braucht HTTPS
2. **SHA-1 Fingerprint** für Android-Build (debug keystore):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore \
     -alias androiddebugkey -storepass android | grep SHA1
   ```
3. **Für Production:** Eigenen Keystore + Release-SHA-1 registrieren

---

## 🛟 Falls etwas nicht klappt

| Fehler | Ursache | Fix |
|--------|---------|-----|
| "Invalid Client" | Falsche Client ID | Nochmal kopieren |
| "Redirect URI mismatch" | URL nicht registriert | Supabase URL hinzufügen |
| "App not verified" | Normal in Dev | "Advanced" → "Go to app" |
| "Network error" | Internet/Supabase | Supabase Status checken |

---

## 📝 Sag mir einfach die Werte

```
GOOGLE_CLIENT_ID:     ???
GOOGLE_CLIENT_SECRET: ???
```

Dann mache ich **A, B, C** automatisch.
