# JHOOMO Organizer — Android App Roadmap

> Organizer app sirf **basic read-only dashboard** hai. Poora organizer panel
> `organizer-web/ROADMAP.md` me hoga. Event create, KYC, gate staff, refunds,
> settlements aur payouts web par jayenge.

---

## App me sirf ye rahega

### 1. Organizer Login

- Same organizer account phone OTP / Google se.
- Server claim `organizer === true` hone par hi organizer dashboard.
- KYC pending ho to dashboard me status dikhe, write actions nahi.

### 2. Basic Dashboard

- Organizer ka naam, city, KYC badge.
- Total events, live events, completed events.
- Total tickets sold and gross sales.
- Aaj ke check-ins.
- Payout status summary (pending / on hold / paid).
- "Open Organizer Web Panel" button.

### 3. My Events

- Apne events ki list.
- Har event: poster, title, date, venue, status.
- Tickets sold, revenue, check-in count.
- Read-only event detail.

### 4. Sales Overview

- Event-wise ticket sales.
- Recent bookings count.
- Refund count summary.
- No customer PII beyond what is needed for support.

### 5. Promoter Performance

- Kis influencer ne kitne ticket sell kiye.
- Promoter name, handle, referral code.
- Clicks, tickets sold, gross revenue, commission.
- Leaderboard sorted by tickets sold.
- Read-only; commission approval web par.

### 6. Web Redirect

- Web panel URL: `https://organizer.jhoomo.com` (proposed).
- App se open karne par browser me organizer web login.
- Staff scanner app link web se generate hoga.

---

## App se remove/disable (web parity ke baad)

- [ ] Create event / DIY wizard
- [ ] KYC form and bank account
- [ ] QR scanner and manual gate lookup
- [ ] Staff and gate access management
- [ ] Settlements and payout release
- [ ] Refund approve/reject
- [ ] Promo code creation
- [ ] Organizer community announcements
- [ ] Edit event
- [ ] Manual payment approvals

---

## Current files that will be replaced or reduced

- `organizer_dashboard_screen.dart` → basic dashboard only.
- `create_event_screen.dart` → move to organizer web.
- `bms_do_it_yourself_screen.dart` → move to organizer web.
- `bms_list_your_show_portal_screen.dart` → app me registration entry only.
- `list_your_show_screen.dart` → app me registration entry only.
- `kyc_status_screen.dart` → web me full KYC; app me status badge only.
- `qr_scanner_screen.dart` → move to new staff app.
- `gate_manual_lookup_screen.dart` → move to new staff app.
- `manage_staff_roles_screen.dart` → move to organizer web.
- `settlements_screen.dart` → move to organizer web.
- `bank_account_settings_screen.dart` → move to organizer web.

---

## Backend Read Contracts Needed

- `organizerDashboard` — KPI cards.
- `organizerListEvents` — paginated own events.
- `organizerEventSummary` — sales/check-in summary.
- `organizerListSales` — recent booking summary.
- `organizerListPromoterPerformance` — per-promoter tickets and commission.

All reads must verify organizer claim and ownership server-side.

---

## Acceptance Criteria

- Organizer app opens directly to the basic dashboard.
- App me koi create/edit/refund/payout/staff action nahi hai.
- App accurately shows event sales and promoter ticket counts.
- "Open Organizer Web Panel" works.
- Organizer web is the only place for operations.
- Admin console Android app me nahi hai.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Settlement/payout + KYC Functions me; PDF/QR generation Functions par; media R2 par; gate scan offline-first.

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
