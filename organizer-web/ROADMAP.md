# JHOOMO Organizer Web Panel — Complete Roadmap

> Product rule: Android app me organizer ko sirf **basic dashboard** milega:
> apne events, sales aur kis influencer ne kitne ticket sell kiye. Event creation,
> KYC, gate staff, refunds, settlements aur poora organizer control web panel me hoga.

---

## 1. Current State

- `organizer-web/` abhi sirf roadmap hai; production web app abhi bana nahi hai.
- Organizer ka poora panel filhaal Android app me hai:
  - Create event / DIY wizard
  - KYC and bank account
  - Gate scanner, manual lookup, staff roles
  - Settlements
  - Promoter dashboard
- App ka organizer dashboard abhi read-only summary ki taraf move ho raha hai.
- Backend organizer callables already available:
  - KYC: `saveKycDraft`, `verifyPanCallable`, `verifyBankCallable`,
    `sendEmailCodeCallable`, `verifyEmailCodeCallable`, `submitKyc`, `getKycStatus`
  - Events: `saveEventDraft`, `submitEventForReview`, `updateLiveEvent`,
    `cancelEvent`, `createPromoCode`, `listMyEvents`
  - Gate: `createStaffPasscode`, `revokeStaff`, `listStaff`, `staffLogin`,
    `endGateSession`, `gateCheckIn`, `manualLookup`, `admitManualLookup`,
    `getGateManifest`, `syncOfflineCheckins`
  - Settlements: `settlementRun`, `approveSettlement`, `listSettlements`
  - Promoters: `becomePromoter`, `requestPromoterPayout`
  - Refunds: `requestRefund`, `organizerApproveRefund`, `organizerRejectRefund`

---

## 2. Product Split: App vs Web

| Capability | Android app | Organizer web |
|---|---|---|
| Login | Yes | Yes |
| Basic dashboard | Yes | Yes |
| Own events list | Yes, summary | Yes, full management |
| Sales/tickets summary | Yes | Yes + export |
| Influencer leaderboard | Yes, read-only | Yes + approve/commission control |
| Event create/edit | No | Yes |
| KYC/bank | No | Yes |
| Gate staff and scanner links | No | Yes |
| Refund decisions | No | Yes |
| Settlements and payouts | No | Yes |
| Promo codes and campaigns | No | Yes |
| Community announcements | No | Yes |
| Reports and analytics | No | Yes |

App dashboard must never expose destructive actions. Web is the source of truth.

---

## 3. Target Architecture

```
organizer-web/
├── src/
│   ├── auth/                 # Organizer Firebase session + claim validation
│   ├── components/           # Shared layout, tables, forms, charts
│   ├── lib/                  # Firebase, callables, formatters, uploads
│   ├── pages/
│   │   ├── Dashboard/
│   │   ├── Events/
│   │   ├── Ticketing/
│   │   ├── Promoters/
│   │   ├── Staff/
│   │   ├── Sales/
│   │   ├── Refunds/
│   │   ├── Settlements/
│   │   ├── Kyc/
│   │   ├── Community/
│   │   ├── Reports/
│   │   └── Settings/
│   ├── routes/
│   └── types/
├── ROADMAP.md
└── ...
```

Recommended stack: React 18 + Vite + TypeScript, same Firebase project and
callable functions as admin-web. Reuse shared UI patterns later via a common package.

### Login

- Same organizer account as Android.
- Firebase Auth: phone OTP and/or Google.
- Server resolves role from claims: `organizer === true`.
- If organizer claim is missing: show "KYC complete karo" with app deep link.
- If account is suspended: allow read-only view and payout status only.
- No influencer/promoter login on this panel.

---

## 4. Route Map (Target)

| Route | Module | Notes |
|---|---|---|
| `/login` | Organizer sign-in | Phone/Google |
| `/` | Dashboard | Basic + full KPIs |
| `/events` | Event list | Drafts, live, completed |
| `/events/new` | Create event | Multi-step wizard |
| `/events/:id` | Event detail | Overview, tickets, staff, sales |
| `/events/:id/edit` | Edit event | Locked fields when live |
| `/events/:id/tickets` | Tiers and inventory | Capacity, pricing, fees |
| `/events/:id/promos` | Promo codes | Limits and attribution |
| `/events/:id/promoters` | Promoter performance | Per-influencer ticket sales |
| `/events/:id/staff` | Gate staff | Create/revoke passcodes |
| `/events/:id/scanner` | Scanner links and sessions | QR/link for staff app |
| `/sales` | Sales and bookings | Search, export |
| `/attendees` | Attendee list | Check-in status |
| `/refunds` | Refund requests | Approve/reject |
| `/settlements` | Payouts | Event-wise ledger |
| `/kyc` | KYC and bank | PAN, bank, email |
| `/community` | Announcements | Event updates |
| `/reports` | Analytics | Sales, traffic, promoters |
| `/settings` | Profile and terms | Organizer preferences |

---

## 5. Module Specifications

### 5.1 Dashboard

- Live cards: gross sales, net payout, tickets sold, check-ins, refunds.
- Upcoming events and status.
- Promoter leaderboard: influencer name, code, clicks, tickets, GMV, commission.
- Alerts: KYC pending, event changes requested, payout on hold, low inventory.
- Date range and event filter.
- Read-only on app; web adds drill-down and actions.

### 5.2 Event Creation Wizard

Steps:

1. Basics: title, category, description, language, age limit.
2. Venue: address, city, map link, capacity.
3. Schedule: date, start/end time, gates open.
4. Media: poster, gallery, terms.
5. Tickets: tiers, price, quantity, sale window, per-user limit.
6. Promoters: commission rate, approval mode, promo budget.
7. Review and submit.

Rules:

- Draft autosave.
- Server-side validation for dates, capacity and pricing.
- Submit goes to admin review.
- Live events allow limited edits; price/capacity changes need audit.

### 5.3 Event Detail

Tabs:

- Overview: status, key numbers, alerts.
- Tickets: tiers, sold, remaining, revenue.
- Promoters: per-influencer performance and commission.
- Staff: gate assignments and passcodes.
- Sales: bookings list with filters.
- Refunds: requests and status.
- Announcements: community post for this event.
- Audit: event change history.

### 5.4 Ticket Tiers and Inventory

- Create/edit tiers while draft.
- Live edits limited to safe fields.
- Capacity and per-user limits.
- Sale start/end.
- Fee preview: platform fee, payment fee, GST, TDS.
- Inventory shards handled by backend; web must show real availability.

### 5.5 Promo Codes

- Create code with discount, usage limit, validity.
- Attribution rules: organizer code vs promoter code.
- Disable code.
- Export redemption list.
- Prevent code collision with referral codes.

### 5.6 Promoters and Influencers

- Invite/approve promoters for an event.
- Commission model: fixed ₹ per ticket or percentage.
- Approval mode: auto-approve or organizer review.
- Per-promoter view:
  - Clicks
  - Tickets sold
  - Gross revenue
  - Commission earned
  - Payout status
- Rank promoters and export CSV.
- Suspend promoter from event.
- Self-referral and fraud flags.

### 5.7 Gate Staff

- Create staff with name, phone, gate, role, validity window.
- Passcode shown once; store only hash.
- Generate staff app link / QR containing event id and staff id.
- Revoke staff and end active sessions.
- View scan count and last login.
- Max staff limit enforced server-side.

### 5.8 Scanner App Link

Organizer will share a link with gate staff:

```
https://<staff-app-domain>/join?eventId=<eventId>&staffId=<staffId>
```

Flow:

1. Staff opens link.
2. If app installed → open app with deep link.
3. If app not installed → show download page.
4. After install/open → staff enters 6-digit passcode.
5. Backend `staffLogin` returns custom token and gate session.
6. Scanner unlocks and screen lock can be enabled.

Link must not contain the passcode.

### 5.9 Sales and Attendees

- Search by booking id, phone, name, tier.
- Filters: event, status, payment, check-in.
- Booking detail: payment, attendee, QR status, refund state.
- Export CSV.
- Resend ticket email/SMS.
- No card data.

### 5.10 Refunds

- Queue with reason, amount, requester.
- Approve/reject with note.
- Refund policy shown before decision.
- Cannot approve above organizer limit; escalate to admin.
- Gateway status and retry state.

### 5.11 Settlements

- Event-wise: gross, platform fee, payment fee, refunds, TDS, GST, net.
- Status: pending, on hold, approved, paid, failed.
- Bank account status.
- Download statement.
- Raise dispute with admin.
- Payout timeline and UTR after release.

### 5.12 KYC and Bank

- PAN verification.
- Business/legal name.
- Bank account and IFSC verification.
- Email verification.
- Status timeline and rejection reasons.
- Resubmit flow.
- No raw PAN in browser storage; mask after submit.

### 5.13 Community Announcements

- Post event update, lineup change, venue change.
- Target: event followers/attendees.
- Preview before publish.
- Admin moderation applies.

### 5.14 Reports

- Sales by day, tier, city, promoter.
- Conversion funnel: views → checkout → paid.
- Refund and check-in rates.
- Promoter ROI.
- Export CSV/XLSX.
- Date and event filters.

### 5.15 Settings

- Organizer profile, support contact.
- Notification preferences.
- Terms acceptance version.
- Team access (read-only finance user, operations user).
- Danger zone: request account closure.

---

## 6. Backend Contracts to Add

- `organizerDashboard` — aggregate KPIs for app and web.
- `organizerListEvents` — paginated events with summary.
- `organizerEventDetail` — event, tiers, staff, promoter summary.
- `organizerListSales` — paginated bookings.
- `organizerListPromoterPerformance` — per-event promoter stats.
- `organizerRefundDecision` — already partially covered.
- `organizerGenerateStaffLink` — signed link metadata.
- `organizerUpdateSettings`.
- `organizerExportSales`.
- `organizerAnnouncementCreate`.

Rules:

- Every callable checks `organizer` claim and event ownership.
- Money in paise.
- Server-side pagination and filters.
- Audit all live-event edits, refunds, staff changes and payouts.
- No client-side commission calculation.

---

## 7. Android App Basic Dashboard (Target)

After web parity, Android organizer shell should contain only:

- Organizer name and KYC badge.
- Events list with status.
- Sales summary per event.
- Promoter performance per event: influencer name, tickets sold, commission.
- Check-in count.
- Payout status summary.
- Button: "Open Organizer Web Panel".
- Read-only; no create/edit/scan/refund/payout actions.

Remove from Android once web is live:

- Create event wizard
- KYC forms
- Gate scanner and manual lookup
- Staff management
- Settlements
- Refund decisions
- Promo code creation
- Bank account settings

Keep only if explicitly needed offline: read-only event and sales cache.

---

## 8. Delivery Phases

### Phase O0 — Foundation

- Scaffold `organizer-web` (Vite + React + TS).
- Firebase auth, claim guard, layout, routing.
- Shared API client and error handling.
- Staging project and hosting target.

### Phase O1 — Read-only parity

- Dashboard.
- Events list and detail.
- Sales list.
- Promoter performance.
- Read-only while Android remains source of operations.

### Phase O2 — Event management

- Create/edit event wizard.
- Ticket tiers and inventory.
- Promo codes.
- Submit for admin review.
- Announcement posts.

### Phase O3 — Gate and staff

- Staff CRUD.
- Passcode generation.
- Staff app links/QR.
- Session monitoring.
- Offline sync reports.

### Phase O4 — Money

- Refund decisions.
- Settlements and statements.
- Bank account and KYC.
- Payout disputes.

### Phase O5 — Analytics and scale

- Reports and exports.
- Team roles.
- Notifications.
- Performance and accessibility pass.

### Phase O6 — Android cleanup

- Reduce Android organizer flow to the basic dashboard.
- Remove organizer operation screens and imports.
- Verify no organizer write path remains on Android except dashboard reads.

---

## 9. Security and Compliance

- Server-side ownership check on every event id.
- No trust in eventId or organizerId from URL.
- Signed upload URLs for posters and documents.
- Mask PAN and bank details.
- Rate limit passcode generation and staff login.
- Staff links expire and can be revoked.
- Audit every finance and staff action.
- Session timeout and re-auth for bank/KYC changes.
- DPDP retention for KYC documents.

---

## 10. Acceptance Criteria

- Organizer can create, submit, edit and pause an event from web.
- Organizer can complete KYC and add a verified bank account from web.
- Organizer can create staff, share a staff link and revoke access.
- Organizer can see exactly which influencer sold how many tickets.
- Organizer can approve refunds and view settlements.
- Android app shows only the basic dashboard and no write actions.
- Every web action is ownership-checked and audit logged.
- No influencer/promoter can log in to organizer web.

---

## 11. Open Decisions

1. Organizer web domain: `organizer.jhoomo.com` or `app.jhoomo.com/organizer`?
2. Login: phone OTP only, Google only, or both?
3. Can an organizer also be a promoter on the same account?
4. Team roles in v1 or later?
5. Offline read-only dashboard required on Android?
6. Settlement statement format for CA/accounting export.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Static organizer web -> Cloudflare Pages; auth Firebase; events/settlement Firebase callables; no separate DB.

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

### 1. Single Domain Setup (`jhoomo.in`)
Organizer portal single domain setup me subdomains par chalega:

| Portal | URL | Hosting & CDN |
|---|---|---|
| Organizer Web Console | `https://organizer.jhoomo.in` | Vercel (Production) + Cloudflare Edge CDN |
| Main Web / Landing | `https://jhoomo.in` | Vercel (Production) + Cloudflare Edge CDN |
| Admin Master Console | `https://admin.jhoomo.in` | Vercel (Production) |
| Backend API & Webhooks | `https://api.jhoomo.in` | Firebase Cloud Functions (asia-south1) |

### 2. High-Traffic Ticket Spike & Concurrency Lock
- **Race Condition Handling (1 Ticket Left, 2 Buyers):**
  - Database me `runTransaction` ke through millisecond check hota hai.
  - Pehle user ko 10-minute ka inventory hold milta hai aur countdown timer chalu ho jata hai.
  - Doosre user ka order block ho jata hai aur UI me real-time "Sold Out" status update ho jata hai (Zero double-booking).
  - Agar payment 10 min me complete nahi hui, toh backend lock release karke ticket wapas live kar deta hai.
