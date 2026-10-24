# JHOOMO Influencer / Promoter — Android App Roadmap

> Influencer/promoter ka poora experience **sirf Android app me** hoga.
> Inka koi web login nahi hoga. App ke andar 4 main tabs:
> **Home (Promoter Dashboard)**, **Community**, **Profile**, **Earnings / Grow**.

---

## 1. Current State

- Promoter onboarding: `become_influencer_promoter_screen.dart`.
- Promoter dashboard: `promoter_dashboard_screen.dart`.
  - My Links
  - Sales Log
  - Generate promo link
  - Copy/share link
  - Clicks, tickets sold, revenue, commission
- Community: `single_community_hub_screen.dart`.
- Profile: `profile_safety_screen.dart` me "My Work" section.
- Backend:
  - `becomePromoter`
  - `requestPromoterPayout`
  - Referral redirect: `referralRedirect`
  - Firestore collections: `promoters`, `referralCodes`, `referrals`,
    `promoter_audit_logs`, `commissions`, `promoterPayouts`.

### Current gaps

- Promoter ke liye dedicated bottom navigation nahi hai; customer shell use kar raha hai.
- Registration ke baad seedha dashboard khulta hai, profile-first flow nahi.
- Earnings/payout screen app me nahi hai.
- Community post composer direct open nahi hota.
- Demo referral data service me hai; production referral flow ko end-to-end wire karna hai.
- Join Campaign tab ka code comment hai, UI me nahi hai.

---

## 2. Target App Structure

Bottom navigation for promoter role:

1. **Home** — Promoter Dashboard
2. **Community**
3. **Earnings / Grow**
4. **Profile**

No separate influencer web app. No web login. Admin/organizer web panels se
influencer credentials accept nahi honge.

```
mobile/lib/screens/promoter/
├── promoter_home_tab.dart          # Dashboard + links + sales
├── promoter_earnings_tab.dart      # Commission, payouts, milestones
├── promoter_shell.dart             # 4-tab bottom navigation
├── become_influencer_promoter_screen.dart
└── ROADMAP.md
```

Existing `promoter_dashboard_screen.dart` ko Home tab me refactor kiya jayega.

---

## 3. Tab 1 — Home (Promoter Dashboard)

### Header

- Name, handle, promoter code, KYC/PAN status badge.
- Payout status summary.

### KPI Cards

- Total clicks.
- Tickets sold.
- Gross revenue driven.
- Commission earned.
- Pending commission.
- Paid commission.

### Active Links

- Event poster, title, date, venue.
- Referral code and link.
- Clicks, tickets sold, commission.
- Copy link / WhatsApp / Instagram share.
- Link status: active, paused, event ended.

### Sales Log

- Real-time list of bookings through promoter code.
- Event, tier, quantity, amount, commission, time.
- Masked buyer name for privacy.

### Join Campaign

- Events open for promoter collaboration.
- Commission rate, approval mode, slots left.
- Request to join / auto-join.
- My campaign requests status.

### Actions

- Generate new promo link.
- Share link.
- Open event details.
- Contact organizer (if enabled).

---

## 4. Tab 2 — Community

- Same community feed as customer.
- Role filter includes Influencer.
- Create post with event tag.
- Promo card attachment with referral link.
- Request collab on organizer posts.
- Like, comment, share, report.
- Moderation rules from admin apply.

---

## 5. Tab 3 — Earnings / Grow

### Earnings

- Available commission.
- Pending commission (escrow).
- Lifetime paid.
- TDS deducted and net payout.
- Payout history with UTR.

### Payout Request

- Minimum payout check.
- Bank account form: account number, IFSC, bank name.
- PAN required for lower TDS.
- Request payout via `requestPromoterPayout`.
- Show TDS preview before submit.

### Grow

- Commission rate per event.
- Top-performing events.
- Milestone progress (example: 10 / 25 / 50 tickets).
- Leaderboard rank.
- Tips to improve conversion.
- Referral link sharing shortcuts.

### Statements

- Monthly earnings statement.
- Download/share statement.
- TDS certificate when applicable.

---

## 6. Tab 4 — Profile

Use the existing profile screen; no separate influencer profile page.

Add/remove options based on role:

- Promoter code and handle.
- Influencer dashboard shortcut.
- My links.
- Earnings and payouts.
- Community posts.
- PAN/KYC status.
- Edit personal details.
- Support.
- Sign out.

Registration entry stays for customers:

- Profile → "Become an Influencer / Promoter".

---

## 7. Registration Flow

```
Customer Profile
  → Become an Influencer / Promoter
  → Name, social handle, phone, PAN
  → Accept promoter terms
  → becomePromoter()
  → Role claim refresh
  → Promoter shell (Home)
```

Rules:

- PAN format validation.
- Unique promoter code.
- Terms version stored.
- Role is server-issued; client cannot self-grant.
- If already promoter, show dashboard instead of registration.

---

## 8. Referral and Commission Flow

1. Promoter generates link: `https://<web>/e/<eventId>?ref=<code>`.
2. Customer opens link; referral code is stored.
3. Customer books and pays via Razorpay.
4. Backend validates code and attribution.
5. Commission record created: pending.
6. Event completes / refund window closes: approved.
7. Promoter requests payout.
8. Admin/organizer releases payout.
9. Promoter sees paid status + UTR + TDS.

Rules:

- Self-referral blocked.
- Duplicate/abusive accounts flagged.
- Commission in paise.
- Refunded bookings reverse commission.
- No client-side commission calculation.

---

## 9. Backend Contracts to Add

- `promoterDashboard` — KPIs and recent activity.
- `promoterListLinks` — active referral links.
- `promoterListSales` — paginated sales log.
- `promoterListCampaigns` — joinable campaigns.
- `promoterJoinCampaign` — request/auto-join.
- `promoterEarnings` — commission summary and history.
- `promoterListPayouts` — payout history.
- `promoterUpdateProfile`.
- `promoterCreatePost` — community post with event tag.

All callables verify `promoter === true` claim and ownership.

---

## 10. Navigation and Role Rules

- Promoter login → `PromoterShell` with 4 tabs.
- Customer can browse community and profile normally.
- Promoter can switch to customer view from profile if needed.
- No admin or organizer operations in promoter shell.
- No web login for promoters.
- Admin can suspend promoter; app shows read-only state.

---

## 11. Delivery Phases

### Phase P0 — Role shell

- Create `PromoterShell` with 4 tabs.
- Login routing for promoter role.
- Profile "My Work" options.
- Remove customer-only tabs from promoter shell.

### Phase P1 — Dashboard

- Refactor current promoter dashboard into Home tab.
- Real Firestore referral data.
- Active links and sales log.
- Join campaign.

### Phase P2 — Community

- Create post with event tag.
- Promo card with referral link.
- Collab requests.

### Phase P3 — Earnings

- Earnings summary.
- Payout request and bank form.
- TDS preview.
- Payout history and statement.

### Phase P4 — Growth

- Milestones.
- Leaderboard.
- Campaign recommendations.
- Conversion tips.

### Phase P5 — Hardening

- Self-referral and fraud checks.
- Offline/error states.
- Analytics events.
- App size and performance pass.

---

## 12. Acceptance Criteria

- Promoter logs in and sees Home, Community, Earnings, Profile tabs.
- Home shows exact tickets sold and commission per event.
- Promoter can generate/copy/share a referral link.
- Booking through link attributes correctly.
- Earnings show pending, approved and paid commission.
- Payout request respects minimum and TDS rules.
- Community post can include an event promo link.
- No web login or organizer/admin action in promoter app.
- All money values in paise and server-calculated.

---

## 13. Open Decisions

1. Promoter home tab default: dashboard or community?
2. Join Campaign: auto-approve or organizer review by default?
3. Payout minimum and schedule.
4. Milestone bonus structure.
5. Can a promoter also be an organizer on the same account?
6. Instagram/WhatsApp share deep-link format.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Referral link/attribution Functions se; dashboard reads paginate; commission ledger Firestore me.

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
