# JHOOMO Community Hub — Screen Architecture & Roadmap

## Overview
The Community Hub provides an Instagram-grade social network built natively into JHOOMO for event attendees, organizers, artists, and influencers.

---

## Active Implemented Architecture

### 1. Feed & Dynamic Role Filter
- **File:** `single_community_hub_screen.dart`
- **Supported Roles:**
  - `ALL`: Unified feed across all local Lucknow events.
  - `ORGANIZER`: Official announcements, collab calls, and host announcements.
  - `INFLUENCER`: Influencer/Promoter discount cards with host-approved affiliate ticket links.
  - `ARTIST`: Behind-the-scenes rehearsal clips, lineup updates, and set times.
  - `SPONSOR`: Partner booth locations, giveaway badges, and VIP invites.
  - `ATTENDEE`: Fan meetups, squad matching, and live venue reviews.

### 2. Instagram-Style Stories Bar
- **Top Carousel:** Circular animated gradient avatar rings displaying live event stories (15s duration).
- **Posting:** Attendees and organizers can tap "+" to post photo/video stories with active event tags.

### 3. Real-Time Broadcast Integration
- **Direct Creator Follow:** Every influencer/organizer post features a dynamic `"Follow & Join"` badge.
- **Auto-Subscription:** Tapping enrolls the attendee directly into the creator's official 1-way broadcast channel in `ChatListScreen` and `UniversalBroadcastChannelScreen`.

### 4. Interactive Engagement & Moderation
- **Likes & Nested Discussions:** Full like toggles, comment count indicators, and pinned comment support.
- **AI Shield Content Moderation:**
  - Prohibited abusive, illegal, scam, and scalping language is automatically caught via `MiloModerationService.checkContentSafety()`.
  - Infractions are blocked instantly, an in-app safety warning notice is pushed to the user, and a critical incident is dispatched to the Admin Moderation Dashboard.
- **3-Dot Context Menu:** Attendees can report posts (`TargetType.post`), report comments (`TargetType.comment`), or block abusive users (`TargetType.user`) via `ReportBlockSheet`.

---

## Future Roadmap

- [ ] **Phase 2 — Direct Voice Notes in Stories:** Allow organizers and artists to post 30-second audio clips directly from backstage.
- [ ] **Phase 3 — Geo-Fenced Venue Snaps:** Stories automatically unlocked only when attendees are detected within 500m of the venue.
- [ ] **Phase 4 — Polls & Q&A Stickers:** Interactive event polls embedded in community posts for crowd song requests.

---

## Free Plan, Hosting & Database Strategy (₹0 se Scale tak)

> **Reality check:** 500k *registered* users free chal sakte hain, 500k *active* users free nahi.
> Free quota **usage** par milta hai, user count par nahi.

**Is module ke liye:** Media-heavy feed/stories -> R2/Cloudinary; comments/likes counters aggregate karo; moderation Functions light rakho.

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
