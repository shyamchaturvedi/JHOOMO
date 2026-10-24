# JHOOMO Customer App — Complete Roadmap

> Customer app feature-wise kaafi bana hua hai, lekin **production complete nahi hai**.
> Sabse bade blockers: demo/mock data fallback, live payment E2E verify nahi hua,
> Firebase deploy access nahi, real event inventory nahi, aur testing/store readiness baaki hai.

---

## 1. Current State

### Built UI / Screens

- Onboarding and phone/Google auth
- Profile setup and role detection
- Main 5-tab shell:
  1. Home
  2. Explore
  3. Community
  4. Saved / Wishlist
  5. Profile
- Event details and ticket tier selection
- Razorpay checkout
- Payment result and booking history
- Ticket detail with QR
- Refund request
- Wishlist
- Community hub and posts
- Event group chat and chat list
- Connection requests and meet-people/radar
- Notifications
- Edit profile
- Safety: SOS, emergency contacts, fake call, privacy shield
- Face verification
- Settings, legal policies, help center
- Referral/promo code handling
- Deep links / app links foundation

### Backend / Services

- Firebase Auth, Firestore, Functions, App Check, Messaging
- Razorpay order creation/verification
- Booking and ticket documents
- Refund request flow
- Community backend
- Promoter/referral attribution
- Account delete/export plumbing
- User profile and privacy settings

---

## 2. Verdict

**Customer app complete nahi hai.**

UI aur core flows lagbhag ready hain, par release ke liye ye missing hai:

- Mock/demo data production paths me pahunch sakta hai.
- Payment, booking, ticket, refund ka live E2E proof nahi hai.
- Functions/rules/storage/webhook deploy nahi hue.
- Real inventory aur real event data ka test nahi hua.
- Automated tests sirf 6 hain; koi integration/E2E test nahi.
- Push notifications, deep links, App Check, and crash reporting production-verified nahi.
- Settings me kuch options no-op hain.
- Store listing, signing, privacy/data-safety, and release hardening baaki hai.

---

## 3. P0 Release Blockers

1. **Live Firebase access**
   - `milo-da65c` / `milo-da65c-staging` project access chahiye.
   - Functions, Firestore rules, storage rules, indexes deploy karo.

2. **Razorpay end-to-end**
   - Keys/secrets bind karo.
   - Create order → checkout → verify → webhook → booking confirmed.
   - Failure, cancel, timeout, duplicate payment, refund test.

3. **Demo/mock removal**
   - Home/Explore/DB fallback `MockData` hatao production me.
   - `ensureSeeded` / demo seeding release me disabled ho.
   - `dandiya_special_screen.dart`, `meet_people_screen.dart`, chat fallback,
     payment approval demo data review karo.
   - Offline screen ka "Continue in Offline Demo Mode" remove ya real offline banao.

4. **Real event data**
   - Firestore me real published events chahiye with tiers, capacity, images.
   - Home/Explore/search/filter real inventory par test karo.
   - Sold-out, low-stock, cancelled event states verify karo.

5. **Production auth**
   - Demo/debug login paths release build se remove.
   - Google Sign-In SHA fingerprints and OAuth config verify.
   - Phone OTP production quota and reCAPTCHA/App Check verify.

---

## 4. Feature Completeness Checklist

### Auth and Onboarding

- [x] Splash, onboarding, phone OTP, Google login
- [x] Profile setup
- [x] Age gate
- [ ] Release demo login fully removed
- [ ] Session expiry and forced logout handling
- [ ] Account recovery / support path
- [ ] Multi-device session behavior defined
- [ ] Auth error copy and retry states

### Home and Explore

- [x] Hero carousel, categories, upcoming events
- [x] Search, category filters, sort
- [x] Event cards and details
- [ ] Hardcoded `Lucknow` city replaced with saved location or user city
- [ ] Real nearby events with geolocation
- [ ] Pagination / infinite scroll
- [ ] Empty, loading, error, and offline states audit
- [ ] Trending/recommended logic
- [ ] Event share deep link verified

### Event Details and Booking

- [x] Event info, tiers, quantity
- [x] Razorpay checkout
- [x] Booking result
- [x] My tickets and ticket QR
- [ ] Real-time inventory and sold-out enforcement
- [ ] Booking hold/expiry handling
- [ ] Duplicate payment and retry recovery
- [ ] Promo code validation UX and server errors
- [ ] Group booking and attendee details (decide if in scope)
- [ ] Booking confirmation email/SMS/WhatsApp (decide channel)
- [ ] Cancelled/rescheduled event handling
- [ ] Refund status timeline

### Tickets

- [x] Ticket list and detail
- [x] QR display
- [ ] Offline ticket access
- [ ] Ticket transfer (decide scope)
- [ ] Add to Google Wallet / calendar (optional)
- [ ] Entry instructions, gate, and venue map
- [ ] Support action from ticket

### Community

- [x] Feed and post creation
- [x] Comments, likes, reporting
- [x] Role-based posting restrictions
- [ ] Production moderation queue verified
- [ ] Image upload limits and compression
- [ ] Block/mute user
- [ ] Post deep links
- [ ] Report status feedback
- [ ] Community guidelines and consent

### Chat and Connections

- [x] Chat list and event group chat
- [x] Connection requests
- [x] Meet people/radar UI
- [ ] Real user discovery data
- [ ] Block/report in chat
- [ ] Media in chat (decide scope)
- [ ] Message push notifications
- [ ] Chat retention and safety rules
- [ ] Remove mock profiles from meet-people flows

### Wishlist and Notifications

- [x] Wishlist
- [x] Notification center
- [ ] Real FCM token registration and topic sync
- [ ] Notification deep links to event/ticket/chat
- [ ] Notification preference enforcement
- [ ] Reminder notifications before event
- [ ] In-app notification badges

### Profile and Settings

- [x] Profile, edit, safety, privacy, legal, help
- [x] Account delete
- [ ] Language selector works (currently placeholder)
- [ ] Location permission action works (currently placeholder)
- [ ] Data export UI complete
- [ ] Notification preferences persist
- [ ] Support/ticket contact flow
- [ ] App version, legal versions, and consent history

### Safety

- [x] SOS, emergency contacts, fake call, privacy shield
- [ ] SOS live location and contact delivery verified
- [ ] Permission-denied fallback
- [ ] Safety settings sync across devices
- [ ] Face verification production/legal review
- [ ] Incident support workflow

### Payments and Refunds

- [x] Razorpay-only flow
- [x] Refund request UI
- [ ] Webhook idempotency verified
- [ ] Refund approval/rejection status in app
- [ ] Payment failure analytics
- [ ] Receipt/invoice
- [ ] GST details if applicable

---

## 5. Customer App Structure (target)

Current screens are directly under `mobile/lib/screens/`. Future organization:

```
mobile/lib/screens/customer/
├── shell/
│   └── customer_shell.dart
├── home/
├── explore/
├── events/
├── booking/
├── tickets/
├── community/
├── chat/
├── wishlist/
├── notifications/
├── profile/
├── safety/
└── ROADMAP.md
```

This is a refactor only after feature freeze; existing files keep working meanwhile.

Customer shell tabs stay:

1. Home
2. Explore
3. Community
4. Saved
5. Profile

No organizer, admin, or scanner actions in the customer shell.
Promoter registration is only an entry point from Profile.

---

## 6. Data and Backend Contracts

Required read/write callables or queries:

- `listPublishedEvents` — city, category, date, pagination.
- `getEventDetails` — event, tiers, inventory, organizer-safe fields.
- `createBookingIntent` / Razorpay order.
- `verifyPayment` and webhook handler.
- `listMyBookings` and `getBooking`.
- `requestRefund` and `getRefundStatus`.
- `toggleWishlist`.
- `listCommunityPosts`, `createPost`, `reportPost`.
- `listNotifications`, `markRead`.
- `registerDeviceToken`.
- `exportMyData`, `deleteMyAccount`.
- `saveNotificationPreferences`.
- `getSafetySettings` / `saveSafetySettings`.

Rules:

- Money in paise and server-calculated.
- Booking status lowercase.
- camelCase booking docs; legacy `payment_requests` snake_case.
- Ownership and claim checks server-side.
- No client trust for ticket validity, refund eligibility, or role.

---

## 7. Testing Plan

### Automated

- Unit tests for pricing, promo, date/city filters, booking mapping.
- Widget tests for home, explore, event details, checkout states, ticket QR.
- Integration tests:
  - Login → browse → book → pay (test mode) → ticket.
  - Wishlist and notification deep link.
  - Refund request.
  - Community post and report.
- Emulator tests for Firestore rules and callable contracts.
- Payment sandbox E2E with webhook.

### Manual device matrix

- Low-end Android (2–3 GB RAM).
- Android 10, 12, 14+.
- Small and large screens.
- Slow network, airplane mode, app kill during payment.
- Camera/QR brightness and cracked screen.

### Current gap

- Only `mobile/test/widget_test.dart`, 6 tests passing.
- No `integration_test/` suite.
- No CI workflow running analyze/test/build.

---

## 8. Security and Compliance

- Release signing and Play App Signing.
- Obfuscation and symbol upload.
- No debug logs with phone, PAN, booking, or payment data.
- Firestore/Storage rules audited for customer read/write scope.
- App Check enforced for callables.
- Root/emulator tamper signals (optional, non-blocking).
- Privacy policy and DPDP consent.
- Account deletion and data export working end-to-end.
- Payment PCI scope stays with Razorpay.
- Permission rationale for location, camera, notifications.
- Data safety form accurate in Play Console.

---

## 9. Performance and Reliability

- Image caching and compression.
- Firestore query pagination and indexes.
- Startup time and cold start budget.
- App size budget; remove unused role screens from customer build if flavors are added.
- Crash reporting and analytics (Firebase Crashlytics/Analytics or equivalent).
- Retry/backoff for network failures.
- Offline ticket cache.
- Deep link fallback for app not installed.
- Force update mechanism if API contract changes.

---

## 10. Delivery Phases

### Phase C0 — Project access and deploy

- Get Firebase project access.
- Deploy functions, rules, indexes, storage rules.
- Configure Razorpay secrets and webhook.
- Configure App Check, FCM, Google OAuth.
- Staging environment verified.

### Phase C1 — Remove demo data

- Remove MockData fallbacks from production paths.
- Disable seeding and demo login.
- Replace meet-people, dandiya, chat, and offline demo data.
- Add real empty/error states.

### Phase C2 — Booking and payment hardening

- Real inventory.
- Payment success/failure/cancel/retry.
- Webhook idempotency.
- Booking recovery after app kill.
- Refund status in app.
- Ticket offline cache.

### Phase C3 — Account, notifications, and safety

- FCM tokens and deep links.
- Notification preferences.
- Data export.
- Language and location settings functional.
- SOS delivery verification.

### Phase C4 — Community and chat

- Production moderation.
- Block/report.
- Media limits.
- Connection flows with real users.

### Phase C5 — QA and store readiness

- Integration tests and CI.
- Device matrix.
- Play Store listing, screenshots, privacy, data safety.
- Internal → closed → production rollout.
- Crash/analytics dashboards and on-call runbook.

---

## 11. Acceptance Criteria

- Customer can install, sign up, and complete profile without demo paths.
- Home/Explore show real published events only.
- Search, city, category, filter, and pagination work on real data.
- Customer can book and pay via Razorpay; booking and ticket appear reliably.
- Payment failure/cancel does not create a paid booking.
- Ticket QR is valid and offline-accessible.
- Refund request shows status updates.
- Wishlist, notifications, and deep links work.
- Community post/report and chat safety actions work.
- Account delete and data export work.
- SOS and safety features deliver as designed.
- No mock/demo data in release builds.
- `flutter analyze`, tests, and release build pass in CI.
- App approved and rolled out on Play Store.

---

## 12. Open Decisions

1. Booking confirmation channel: email, SMS, WhatsApp, or in-app only?
2. Ticket transfer allowed or not?
3. Chat media support in v1?
4. Face verification mandatory or optional?
5. Nearby events using precise location or city-level only?
6. Refund automation vs manual organizer/admin approval?
7. Android only launch or iOS later?
8. Single app with role shells vs separate customer/promoter builds?
9. Minimum Android version and device support.
10. Support SLA and in-app escalation path.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** App reads Firestore se; pagination + cache; Razorpay + OTP cost control; Crashlytics/Sentry add karo.

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

---

## 13. Production Scale Architecture (1,000,000+ Users & 1 Domain Setup)

### 1. Single Domain & App Links (`jhoomo.in`)
Mobile app me deep links aur universal links single domain `jhoomo.in` se handle honge:
- `https://jhoomo.in/e/:eventId` -> App ke andar seedha Event details screen open hogi.
- `https://jhoomo.in/c/:code` -> Influencer/promoter promo code auto apply hoga.

### 2. 10 Lakh (1M+) Users Traffic & Crash Protection
- **Local Cache & Offline Persistence:** Mobile app Firestore local persistence ke through previous visited events offline cache rakhti hai. Repeat visits me zero server reads lagte hain.
- **Edge Media Delivery:** Event banners aur images Cloudflare R2 / CDN ke through compressed WebP format me deliver honge taaki app 60 FPS par smooth chale.

### 3. Flash Booking Concurrency Rule (1 Ticket vs 2 Users)
- **Millisecond Winner:** Jab 2 user ek sath aakhri ticket book karte hain, Firestore transaction jo 1 millisecond pehle aata hai use ticket hold de deta hai.
- **Instant Sold Out UI:** Doosre user ko turant clear alert milta hai aur paise katne se pehle order terminate ho jata hai.
- **10-Min Release:** Pehle user ke cancel ya timeout hone par ticket auto-release hokar wapas available ho jati hai.
