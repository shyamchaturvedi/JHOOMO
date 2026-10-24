# JHOOMO Staff Scanner App — Complete Roadmap

> Naya standalone QR scanner app sirf **gate staff** ke liye hoga.
> Organizer web panel se staff link share karega. App install nahi hai to download
> page khulega, install ke baad passcode se login hoga. Scanner me **Screen Lock**
> toggle hoga: jab tak ON hai, app se back nahi ho sakega.

---

## 1. Product Goal

- Customer app se scanner completely alag rakhna.
- Organizer web se staff member create karke ek link/QR share karega.
- Staff link se app install/open karke 6-digit passcode se login karega.
- Login ke baad sirf assigned event + gate ka scanner milega.
- Screen Lock ON hone par accidental back, navigation aur app switching minimize ho.
- Offline scans queue ho aur network aane par sync hon.
- Duplicate entry prevention server-side.

---

## 2. Current Backend Support

Already available in `functions/src/gate/`:

- `createStaffPasscode` — organizer creates staff, returns passcode once.
- `revokeStaff` — revoke staff and active sessions.
- `listStaff` — staff list for an event.
- `staffLogin` — validates eventId + staffId + 6-digit passcode + deviceId,
  creates custom token, returns gate session.
- `endGateSession` — end scanner session.
- `gateCheckIn` — scan validation.
- `manualLookup` — manual phone/booking lookup.
- `admitManualLookup` — manual admission.
- `getGateManifest` — offline manifest fallback.
- `syncOfflineCheckins` — offline queue sync.

Collections:

- `events/{eventId}/staff/{staffId}`
- `staffSecrets/{eventId}_{staffId}`
- `gateSessions/{sessionId}`
- booking/check-in data under event bookings.

Backend rules already include:
- Passcode hashing with salt.
- Lockout after 5 failed attempts.
- Validity window.
- Rate limits by IP and staff.
- Custom claims: `gate_staff`, `eventId`, `gate`, `staffId`.
- App Check on staff login.

---

## 3. Staff Link Flow

Organizer web generates:

```
https://<staff-domain>/join?eventId=<eventId>&staffId=<staffId>
```

Optional QR contains the same URL.

Flow:

1. Organizer web creates staff and shares link.
2. Staff opens link on Android phone.
3. **If app installed:** Android App Link opens scanner app with eventId/staffId.
4. **If app not installed:** landing page shows app download button and steps.
5. After install, link opens app or user pastes link.
6. App validates eventId/staffId and shows staff name/gate/event preview.
7. Staff enters 6-digit passcode.
8. Backend `staffLogin` returns custom token + session id.
9. App signs in with custom token.
10. Scanner screen opens with Screen Lock toggle.

Important:

- Passcode link me **nahi** hoga.
- Link revocable hai; revoked staff par login fail hoga.
- Link expiry event validity window se control hoga.

---

## 4. Target App Architecture

```
staff-app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── config.dart
│   ├── services/
│   │   ├── staff_auth_service.dart
│   │   ├── gate_scan_service.dart
│   │   ├── offline_queue_service.dart
│   │   ├── device_lock_service.dart
│   │   └── deep_link_service.dart
│   ├── screens/
│   │   ├── join_screen.dart
│   │   ├── login_screen.dart
│   │   ├── scanner_screen.dart
│   │   ├── manual_lookup_screen.dart
│   │   ├── session_screen.dart
│   │   └── error_screen.dart
│   ├── widgets/
│   └── theme/
├── android/
│   ├── app/src/main/AndroidManifest.xml   # App Links + Lock Task config
│   └── ...
├── web/                                    # Download/landing page (optional)
└── ROADMAP.md
```

Recommended: Flutter (reuse existing scanner/theme code) with minimal dependencies.
No customer app features, no feed, no bookings, no payments.

---

## 5. Screens

### 5.1 Join / Download Screen

- Event name, gate name, staff name preview (safe fields only).
- "Open Scanner App" button.
- If app missing: "Download Staff App" + install steps.
- Invalid/revoked link error.
- No passcode on this screen.

### 5.2 Staff Login

- Event + gate + staff name.
- 6-digit passcode input.
- Device id generated and stored locally.
- Remember session for event validity window.
- Failed attempt lockout message with retry timer.
- No phone/email login.

### 5.3 Scanner Screen

- Full-screen camera scanner.
- Scan result states:
  - Valid → green, attendee name/tier, admit.
  - Duplicate → red, already checked in time/gate.
  - Invalid → red, reason.
  - Wrong event/gate → warning.
- Manual lookup button.
- Today's scan count and last sync time.
- Offline mode indicator.
- **Screen Lock toggle**.
- End session (requires unlock).

### 5.4 Manual Lookup

- Search by phone or booking id.
- Show booking, tier, quantity, check-in status.
- Admit manually with reason.
- Audit trail server-side.

### 5.5 Session Info

- Event, gate, staff, validity window.
- Device id, app version.
- Scans this session.
- Pending offline sync count.
- Force sync.
- End session.

### 5.6 Screen Lock Mode

Toggle: ON/OFF.

When ON:

- Back button disabled.
- Bottom navigation and drawer hidden.
- App resumes locked state after call/notification.
- Screen kept awake while scanner is visible.
- Optional overlay asking for long-press + PIN to unlock.
- Scanner remains the only active screen.

When OFF:

- Back allowed.
- Session info and manual lookup accessible.
- End session available.

### Android reality (important)

- Ordinary Android apps cannot fully block incoming calls or system UI.
- Best-effort lock:
  - Disable back.
  - Keep scanner foreground.
  - Re-lock on resume.
  - `FLAG_KEEP_SCREEN_ON`.
- Strong lock/kiosk requires one of:
  - Android **Lock Task Mode** with device owner provisioning.
  - Dedicated staff devices enrolled as device owner.
  - MDM/kiosk browser/app mode.
- Roadmap should support two modes:
  1. **Soft Lock** — any Android phone, no device owner.
  2. **Kiosk Lock** — organizer-issued device, device owner, full lock.

Calls:

- Incoming call may still appear in soft lock.
- On call end, app returns to locked scanner.
- Kiosk mode can restrict notifications and app switching.

---

## 6. Offline Scanning

- On login, download gate manifest.
- Cache booking ids + QR token hashes + status.
- Allow scans offline with local duplicate check.
- Queue scans with timestamp, device id, gate, staff id.
- Sync when network returns.
- Conflict resolution:
  - Server wins for already-checked-in.
  - Show conflict list to staff/gate lead.
- Manifest refresh every N minutes when online.
- Manifest expiry warning.

---

## 7. Backend Contracts to Add

- `staffSessionRefresh` — validate custom token/session still active.
- `staffGateManifest` — optimized manifest payload with version/etag.
- `staffScanBatch` — batch offline sync with idempotency keys.
- `staffHeartbeat` — last seen, app version, battery/lock state.
- `staffSessionEnd` — already `endGateSession`.
- `staffIncidentReport` — scanner issue, duplicate dispute, device problem.

Rules:

- Every scan idempotent.
- Server validates event, gate, staff, session and validity.
- No client-side "valid" decision without server confirmation online.
- Offline decisions are provisional until synced.
- Log device id and app version.

---

## 8. Security

- App Check enforced on auth and scan callables.
- Passcode never stored in plain text.
- Custom token short-lived.
- Session bound to device id.
- Revoke staff ends sessions immediately.
- Root/jailbreak detection optional for kiosk devices.
- No customer PII beyond name/tier needed at gate.
- Screenshot protection optional in kiosk mode.
- Force update if app version below minimum.

---

## 9. Delivery Phases

### Phase S0 — Scaffold

- New Flutter app with minimal dependencies.
- Firebase init, App Check, environment config.
- Deep link handling for `/join`.
- Staff login with passcode.
- Basic scanner and valid/invalid states.

### Phase S1 — Organizer integration

- Organizer web staff link generation.
- App Links verification.
- Download/landing page.
- Revoke and validity handling.

### Phase S2 — Offline

- Gate manifest.
- Offline queue.
- Batch sync and conflict UI.
- Sync status and retry.

### Phase S3 — Screen Lock

- Soft lock toggle.
- Back disabled, keep awake, re-lock on resume.
- Unlock gesture + PIN.
- Kiosk mode for device-owner devices.
- Heartbeat and remote session end.

### Phase S4 — Operations

- Manual lookup and admit.
- Incident reporting.
- Session info and force sync.
- Staff performance counts.

### Phase S5 — Hardening

- Force update.
- Crash reporting.
- Battery/performance pass.
- Device compatibility matrix.
- Store listing and internal testing track.

---

## 10. Acceptance Criteria

- Organizer creates staff and shares a link.
- Staff without app sees download page.
- Staff with app opens link and logs in with passcode.
- Invalid/revoked/expired staff cannot log in.
- Valid QR admits once; duplicate scan is blocked.
- Offline scans queue and sync without duplicates.
- Screen Lock ON hone par back se app nahi nikalti.
- Call ke baad app locked scanner par wapas aati hai.
- Kiosk mode device-owner device par full lock deta hai.
- No customer, organizer or admin features in scanner app.

---

## 11. Open Decisions

1. App name: "JHOOMO Staff", "JHOOMO Gate", or "Milo Scanner"?
2. Soft lock default ON or OFF?
3. Unlock method: long-press, PIN, or both?
4. Kiosk devices organizer khareedega ya staff ke phone use honge?
5. Offline manifest size limit per event.
6. Minimum Android version and supported device list.
7. Play Store public listing or internal/closed track only?

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Staff scanner app offline-first; QR verify local + Functions fallback; kam reads/writes; small device footprint.

### Recommended stack (isko sustain karo)

| Layer | Primary (keep) | Free tier | Alternate (backup) |
|---|---|---|---|
| Landing / marketing | **Cloudflare Pages** | Unlimited static + bandwidth | Vercel Hobby (non-commercial), Netlify 100GB/mo |
| Admin / Organizer web | **Cloudflare Pages** | Unlimited static | Firebase Hosting (10GB, 360MB/day) |
| App backend | **Firebase Blaze Functions** (asia-south1) | 2M invocations + 400k GB-s/mo | Supabase Edge Functions |
| Database (NoSQL) | **Firestore** | 50k reads / 20k writes / 20k deletes **per day**, 1 GiB | MongoDB Atlas 512MB, Appwrite Cloud |
| Database (SQL alternate) | **Neon Postgres** | 0.5GB, auto-suspend | Supabase Postgres 500MB, Turso 9GB |
| Auth | **Firebase Auth** | Free (phone OTP SMS paid) | Supabase Auth (50k MAU) |
| Media / images | **Cloudflare R2** | 10GB storage, **free egress** | Cloudinary 25GB, Firebase Storage 5GB |
| SMS / OTP | MSG91 / 2Factor via Functions | Pay per SMS | Firebase Phone Auth |
| Crash / analytics | **Firebase Crashlytics + Sentry** | Free tier | - |

### Kise "khara" rakhe (final decision)

- **Keep (production):** Firebase (app already integrated) + Cloudflare Pages/R2 (static + media, unlimited egress).
- **Backup only:** Supabase / Neon (jab SQL ya heavy reporting chahiye), MongoDB Atlas (NoSQL fallback).
- **Avoid:** ek hi waqt me 2 primary DB production me connect karna - sync/consistency issues honge. Ek primary, ek read-replica/export.

### Free limits jo 500k par phodenge

- 25k DAU x 20 reads = **5L reads/day** vs 50k free = **10x over**.
- Landing page Firebase Hosting par 500k visitors = 360MB/day limit break -> **Cloudflare Pages** use karo.
- Cloud Functions Spark par nahi chalte -> **Blaze mandatory**, budget alert + maxInstances cap lagao.
- Razorpay, SMS, Storage egress kabhi free nahi hote.

### Migration triggers (kab switch kare)

- Firestore reads > 1M/day ya bill > $50/mo -> Postgres (Neon/Supabase) + read cache.
- Media egress free limit cross -> R2 / Cloudinary.
- OTP cost badhe -> Google/email sign-in primary, phone optional.
- Functions latency badhe -> Cloud Run par heavy endpoints shift.

### Estimated cost at 500k registered (~25k DAU)

- Firebase Blaze ~ **$20-50/mo**, SMS ~ **₹4-6k/mo**, Razorpay **2%/txn**.
- **Bilkul ₹0 par 500k active users** kisi managed backend par possible nahi.

### Crash-proof checklist

- [ ] Har list me pagination (limit 20) + Firestore offline persistence.
- [ ] Composite indexes + count() aggregation; bade collection par realtime listener nahi.
- [ ] Static/config data cache karo; media compress + CDN.
- [ ] App Check + security rules + rate limiting enforce.
- [ ] Functions maxInstances cap + budget alerts.
- [ ] Crashlytics/Sentry + release-build testing.
