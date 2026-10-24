# JHOOMO Admin Console — Complete Web Roadmap

> Product rule: **Admin ka poora kaam sirf web par hoga.** Android app me admin console,
> admin actions, admin analytics aur admin login kuch bhi nahi rahega. App sirf customer,
> organizer (basic dashboard) aur influencer/promoter ke liye hai.

---

## 1. Current State

### Already in this folder

- React 18 + Vite + TypeScript admin app.
- Firebase Auth email/password login.
- Custom-claim based admin access with `adminLevel` (`L1`, `L2`, `L3`).
- Active routes:
  - `/login`
  - `/` Dashboard
  - `/kyc`
  - `/events`
  - `/refunds`
  - `/settlements`
  - `/reports`
  - `/promoters`
  - `/support`
  - `/config`
  - `/audit`
- Existing pages: Dashboard, KycQueue, EventReview, Refunds, Settlements,
  UsersReports, Promoters, SupportDesk, AppConfig, AuditLog.
- Existing backend callables in `functions/src/admin/console.ts`:
  `adminDashboardStats`, `adminReviewKyc`, `adminReviewEvent`,
  `adminDecideRefund`, `adminReleaseSettlement`, `adminFraudAction`,
  `adminUserAction`, `adminPromoterAction`, `adminUpdateConfig`,
  `adminSendCampaign`, `adminListReports`, `adminResolveReport`,
  `adminListAuditLogs`, `adminListKycQueue`, `adminListEventQueue`,
  `adminListRefunds`, `adminListSettlements`, `adminListPromoters`,
  `adminSearchUsers`, `adminGetConfig`, `adminListFraudFlags`.

### Current gaps

- Admin app removal from Android is incomplete: admin role still exists in mobile
  session/profile logic, even though the mobile admin screen was removed.
- Admin pages need production polish: pagination, filters, empty/error states,
  CSV export, bulk actions, and consistent confirmation dialogs.
- No dedicated modules yet for:
  - Live event operations
  - Community moderation
  - Staff/scanner session monitoring
  - Finance ledger and reconciliation
  - Notification campaigns
  - Support/help CMS
  - Admin user and role management
  - System health and integrations
  - Data export and retention
- No shared design system with the future organizer web panel.
- No automated E2E tests for permission levels and critical money actions.

---

## 2. Target Architecture

```
admin-web/
├── src/
│   ├── auth/                 # Firebase session + admin claim validation
│   ├── components/           # Layout, tables, drawers, guards, shared UI
│   ├── lib/                  # Firebase, callables, formatters, exporters
│   ├── pages/                # One folder per admin module
│   ├── routes/               # Route map + level guards
│   └── types/                # API contracts and view models
├── ROADMAP.md
└── ...
```

### Access model

| Level | Scope | Typical users |
|---|---|---|
| L1 | Read + low-risk operations, support, refunds up to limit, settlement view | Support lead, finance executive |
| L2 | KYC, event approval, promoter moderation, reports, audit | Operations manager |
| L3 | Config, large refunds, payout release, admin/role changes, kill switches | Founder / super admin |

Rules:

- Admin access only from Firebase custom claims: `admin === true` and `adminLevel`.
- Never trust local storage, URL params, or client-side role values.
- Every mutating action writes `auditLogs` with actor, target, before/after, reason, request id.
- Money actions require a reason and an explicit confirmation.
- Four-eyes approval for high-value refunds and payouts.

---

## 3. Route Map (Target)

| Route | Module | Minimum level |
|---|---|---|
| `/login` | Admin sign-in | Public |
| `/` | Operations dashboard | L1 |
| `/kyc` | Organizer KYC queue | L2 |
| `/organizers` | Organizer accounts and health | L2 |
| `/events` | Event review and moderation | L2 |
| `/events/live` | Live event operations monitor | L2 |
| `/bookings` | Booking search and inspection | L2 |
| `/refunds` | Refunds and disputes | L1 |
| `/settlements` | Settlement and payout control | L1 |
| `/finance` | Ledger, reconciliation, TDS/GST | L1 |
| `/promoters` | Promoter approvals and commissions | L2 |
| `/community` | Community moderation | L2 |
| `/reports` | User reports and fraud flags | L2 |
| `/support` | Support desk | L1 |
| `/staff` | Gate staff and scanner sessions | L2 |
| `/notifications` | Push/SMS/email campaigns | L2 |
| `/content` | Help articles, banners, legal copy | L2 |
| `/config` | App config, fees, feature flags | L3 |
| `/admins` | Admin users and levels | L3 |
| `/audit` | Append-only audit log | L2 |
| `/system` | Integration health and jobs | L3 |

---

## 4. Module Specifications

### 4.1 Admin Login and Session

- Firebase email/password login.
- Read ID token claims after login.
- Reject non-admin or inactive admin.
- Show level badge and environment badge (staging/production).
- Session expiry warning; forced re-auth for L3 money actions.
- No public sign-up.

### 4.2 Operations Dashboard

- Live KPIs: GMV, bookings, check-ins, refunds, payouts, active events.
- Today/7-day/30-day range selector.
- Alerts: failed webhooks, pending KYC, events awaiting review, payout holds,
  SOS incidents, support SLA breaches.
- Drill-down links to filtered module views.
- Staging vs production separation.

### 4.3 KYC Review

- Queue filters: submitted, under review, approved, rejected, suspended.
- Masked PAN/bank by default; reveal requires L2+ and is audit logged.
- Documents preview (signed URLs, short expiry).
- Decision actions: approve, request info, reject, suspend.
- Reason required for reject/request-info/suspend.
- Organizer timeline: submission, verification attempts, admin actions.
- Uniqueness conflict warnings (PAN/bank/phone reuse).

### 4.4 Organizer Accounts

- Search by name, phone, email, organizer id.
- KYC status, live events count, sales, payout status.
- Suspend/reactivate organizer.
- View staff list, settlements, disputes.
- Impersonation is **not** allowed; use audited support view only.

### 4.5 Event Review

- Status filters: draft, pending review, live, paused, completed, cancelled.
- Review checklist: poster, venue, date, age limit, tiers, fees, refund policy,
  lineup, terms, organizer KYC.
- Approve, request changes, reject, pause, force-cancel.
- Duplicate event detection.
- Live event safety checks (capacity, gate staff assigned, scanner active).

### 4.6 Live Event Operations

- Per-event command view: sales velocity, inventory, check-in count, gate status.
- Gate scanner sessions: device, staff, last seen, scan count.
- Incident feed: SOS, manual lookups, duplicate scans, offline sync backlog.
- Emergency controls: pause sales, close gate, publish notice, force sync.
- All emergency actions require L2+ and reason.

### 4.7 Bookings and Tickets

- Search by booking id, user phone, event, payment id.
- View payment, tier, quantity, attendee, QR status, check-in history.
- Resend ticket, invalidate ticket (fraud only), issue manual refund.
- No card data storage; show only gateway references.

### 4.8 Refunds and Disputes

- Queue by status and age.
- Refund limits by level; above limit requires second L3 approval.
- Gateway refund status polling and retry.
- Reason and customer communication preview.
- Prevent refund on already-settled bookings without finance approval.

### 4.9 Settlements and Payouts

- Event-level settlement preview: gross, fees, TDS, GST, refunds, net.
- Hold/release/retry actions.
- Four-eyes approval above threshold.
- Bank account verification status.
- Export settlement statement.
- Failure queue with vendor error messages.

### 4.10 Finance Ledger

- Double-entry style view of bookings, refunds, commissions, payouts, fees.
- Date range, event, organizer, promoter filters.
- Reconciliation: Razorpay settlement vs internal ledger.
- Unmatched payments and missing webhooks queue.
- CSV/XLSX export with signed, expiring download links.
- TDS/GST summaries and financial-year view.

### 4.11 Promoters and Commissions

- Promoter applications and status.
- Referral code lookup, self-referral flags.
- Commission totals: pending, approved, paid.
- Approve/suspend promoter.
- Payout requests and TDS deduction view.
- Fraud signals: same device, same bank, circular referrals.

### 4.12 Community Moderation

- Feed queue for reported posts/comments.
- Role filter: customer, organizer, promoter, artist, sponsor.
- Actions: approve, hide, delete, warn, suspend poster.
- Collab request review.
- Moderation policy notes and audit trail.
- AI moderation flags with confidence score.

### 4.13 Reports and Fraud

- Report queue with severity and SLA.
- Fraud flags: duplicate accounts, payment abuse, scalping, referral abuse.
- User actions: warn, ghost, suspend, ban, restore.
- Case notes and evidence attachments.
- Search user by phone/email/uid with masked PII.

### 4.14 Support Desk

- Ticket queue by category and SLA.
- Safety tickets get highest priority and 4-hour SLA.
- Reply templates, internal notes, attachments.
- Link ticket to booking/event/user.
- Resolve, reopen, escalate.
- CSAT capture.

### 4.15 Gate Staff and Scanner Sessions

- Staff list by event, gate, status, validity window.
- Create/revoke staff passcode (passcode shown once).
- Active scanner sessions and devices.
- Force-end session.
- Offline check-in sync backlog and conflicts.
- Gate manifest download fallback.

### 4.16 Notifications and Campaigns

- Compose push/SMS/email campaign.
- Audience builder: city, role, event attendees, promoter audience.
- Test send, schedule, cancel.
- Delivery, open and failure stats.
- Compliance: consent, quiet hours, unsubscribe.

### 4.17 Content and Legal

- Help center articles.
- Banners and featured events.
- Terms, privacy, refund policy versions.
- Publish requires L2+; version history and audit.

### 4.18 App Config and Feature Flags

- Fee config, limits, TDS thresholds, payout windows.
- Kill switches: payments, community, promoter payouts, new organizer signups.
- Maintenance mode.
- Versioned changes with rollback.
- Changes apply on next app launch; show propagation note.

### 4.19 Admin Users and Roles

- Invite admin by email.
- Assign level L1/L2/L3.
- Deactivate admin.
- Require re-auth for level changes.
- Cannot remove your own last L3 access.

### 4.20 Audit Log

- Append-only table with actor, action, target, before/after, reason, IP, request id.
- Filters by actor, action, target, date.
- Export to CSV.
- Retention policy and BigQuery sink.

### 4.21 System Health

- Webhook health and retries.
- Scheduler job runs.
- Vendor status: Razorpay, SMS, KYC, email.
- Firebase quota warnings.
- Failed jobs with safe retry.

---

## 5. Backend Contracts

Existing callables should remain the only write path. Add where needed:

- `adminListOrganizers`, `adminGetOrganizer`, `adminOrganizerAction`
- `adminListBookings`, `adminGetBooking`
- `adminListFinanceLedger`, `adminReconcilePayments`
- `adminListCommunityQueue`, `adminCommunityAction`
- `adminListStaffSessions`, `adminEndStaffSession`
- `adminListCampaigns`, `adminCreateCampaign`, `adminCancelCampaign`
- `adminListAdmins`, `adminSetAdminLevel`
- `adminSystemHealth`
- `adminExportData`

Conventions:

- Money in paise.
- Booking docs camelCase; legacy `payment_requests` snake_case.
- All admin callables enforce claims server-side.
- All mutations write audit logs.
- List endpoints support cursor pagination and server-side filters.
- Exports are generated server-side into private storage with short-lived URLs.

---

## 6. Android App Cleanup Checklist (after web parity)

- [ ] Remove every admin screen, route, widget and service import from `mobile/`.
- [ ] Remove admin role from mobile session/profile selectors.
- [ ] If an admin signs in on Android, show: "Admin console is web-only" and sign out.
- [ ] Remove admin deep links and push actions that open mobile admin screens.
- [ ] Keep admin push notifications as web links only.
- [ ] Verify release build has no admin strings, assets or dead code.
- [ ] Verify `LoginRouter` never returns an admin screen.

---

## 7. Delivery Phases

### Phase A0 — Stabilise existing admin web

- Fix pagination, filters, empty/error states.
- Standardise confirmations and audit reasons.
- Add level-aware UI guards for every action.
- Add tests for L1/L2/L3 route and action access.
- Finish staging/production environment switch.

### Phase A1 — Money and risk

- Finance ledger.
- Refund limit and four-eyes approval.
- Settlement reconciliation.
- Promoter payout/TDS view.
- Fraud and abuse queues.

### Phase A2 — Live operations

- Live event command view.
- Staff/scanner session monitor.
- SOS and incident feed.
- Emergency controls.

### Phase A3 — Content and growth

- Community moderation.
- Campaign builder.
- Help/legal CMS.
- Banner and featured event control.

### Phase A4 — Governance

- Admin user management.
- System health.
- Data export and retention.
- BigQuery audit sink.
- Quarterly access review.

---

## 8. Security and Compliance

- Enforce App Check for web callables where practical.
- Require re-auth for L3 money and config actions.
- Mask PAN, bank account and phone by default.
- Never log full PAN, bank account, tokens or secrets.
- Signed URLs for documents and exports with short TTL.
- Rate limit admin login and sensitive actions.
- Audit every read of sensitive PII.
- DPDP: data minimisation, retention policy, deletion workflow.
- Incident runbook for admin account compromise.

---

## 9. Acceptance Criteria

- Admin can complete KYC, event approval, refund, settlement, promoter,
  support, config and audit workflows without using the Android app.
- L1 cannot perform L2/L3 actions, and L2 cannot perform L3 actions.
- Every money mutation appears in audit log within 5 seconds.
- All list views handle 0, 1, 1000+ rows with pagination.
- No secret or full PII appears in browser console or logs.
- Android release build contains zero admin UI.

---

## 10. Open Decisions

1. Separate admin subdomain (`admin.jhoomo.com`) vs path (`/admin`)?
2. Razorpay reconciliation: automatic daily job or manual upload first?
3. Four-eyes threshold for refunds and payouts.
4. Admin session length and re-auth frequency.
5. Community moderation: in-house only or vendor-assisted?
6. Data retention period for audit logs and support tickets.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Static React admin -> Cloudflare Pages; saara data Firebase callables (admin*) se; heavy exports Functions me, browser me nahi.

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
Aapke single domain `jhoomo.in` par subdomains ke through complete portals map honge:

| Portal | URL | Hosting & CDN |
|---|---|---|
| Main Landing & Web App | `https://jhoomo.in` | Vercel (Production) + Cloudflare Edge CDN |
| Organizer Web Console | `https://organizer.jhoomo.in` | Vercel (Production) + Cloudflare Edge CDN |
| Admin Master Console | `https://admin.jhoomo.in` | Vercel (Production) + Level L1/L2/L3 Guards |
| Backend API & Webhooks | `https://api.jhoomo.in` | Firebase Cloud Functions (asia-south1) |

### 2. 10 Lakh (1M+) Users Traffic & Crash Protection
1. **Edge Caching via Cloudflare:** Public read requests (event listings, banners, details) Edge cache se direct 0.01s me serve honge bina server par load dale.
2. **Offline Local Persistence:** Mobile app me local snapshot caching enabled hai jisse 80% repeat database queries zero ho jaati hain.
3. **Vercel Global Edge Network:** 10 lakh users bhi ek sath portals visit karein toh assets globally distributed Edge nodes se render honge.

### 3. Flash Booking Concurrency Rule (1 Ticket vs 2 Users)
- **Zero Double-Booking Guarantee:** Jab 2 user ek hi waqt par aakhri 1 ticket book karne aate hain, backend me **Atomic Firestore Transaction** run hota hai.
- Jo request 1 millisecond pehle aati hai, uske liye 10-minute temporary inventory lock lagta hai aur available tickets `0` ho jaate hain.
- Doosre user ko turant safe message milta hai: *"Tier Sold Out!"* — user ke paise kabhi nahi katenge.
- Agar pehla user 10 minute me pay nahi karta ya cancel karta hai, toh backend inventory lock release karke ticket wapas open kar deta hai.
