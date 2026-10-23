# JHOOMO Promoter & Influencer Hub — Screen Architecture & Roadmap

## Overview
The Promoter & Influencer Hub empowers creators, micro-influencers, and campus ambassadors to monetize their audience transparently by partnering with event organizers on JHOOMO.

---

## Active Implemented Architecture

### 1. Onboarding & Registration Screen
- **File:** `become_influencer_promoter_screen.dart`
- **Features:**
  - Profile setup with Instagram handle, follower tier, and category tags (Nightlife, Tech, Food, Dandiya, Music).
  - Organizer auto-approval preferences (auto-accept or manual host review).
  - Instant submission and profile activation.

### 2. Influencer Dashboard & Revenue Tracker
- **File:** `promoter_dashboard_screen.dart`
- **Core Capabilities:**
  - **Live Campaign Matrix:** Active campaigns, click counts, ticket conversions, and verified GMV.
  - **Unique Affiliate Links:** Generates dynamic tracking links (`milo.live/e/{id}?ref={handle}`) with one-tap copy and WhatsApp/IG story sharing.
  - **Commission Safeguard:** Influencers earn commission configured by organizers per ticket (fixed ₹ or % based on host settings). Influencers cannot create arbitrary discount codes — only organizer-approved promo codes can be distributed.
  - **Payout Transparency:** Shows pending vs. available commission balance, payout schedules (5–7 business days post-event), and bank settlement history.

### 3. Community Collab Integration
- Direct collaboration discovery inside `single_community_hub_screen.dart` where creators can tap `"Request Collab"` on events marked `"Creator Collab Open"`.
- Official Influencer Posts display a high-conversion booking card featuring the influencer's official promo discount and live booking counter.

---

## Future Roadmap

- [ ] **Phase 2 — Multi-Tier Milestone Bonuses:** Unlock bonus payouts (e.g. +₹2,000 extra) when an influencer crosses 50 ticket sales.
- [ ] **Phase 3 — Instagram Story Direct Integration:** Deep linking directly into Instagram Story camera with official JHOOMO sticker overlays.
- [ ] **Phase 4 — Instant Payouts via UPI:** Payout disbursement via UPI Autopay once organizer marks settlement complete.
