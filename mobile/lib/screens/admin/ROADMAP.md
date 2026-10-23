# JHOOMO Admin Command Center — Screen Architecture & Roadmap

## Overview
The Admin Command Center gives super-admins complete visibility and decisive governance over listings, attendees, settlements, fraud, and community safety.

---

## Active Implemented Architecture

### 1. Unified Admin Dashboard
- **File:** `admin_dashboard_screen.dart`
- Multi-tab command interface:
  - **Overview & GMV:** Real-time platform gross merchandise value, ticket sales velocity, active cities, and category share.
  - **Event Listing Approvals:** Review new organizer submissions, inspect venue & tax documents, and Approve or Reject with custom feedback.
  - **Financial Settlements:** Authorize bank payouts to organizers after verifying event completion.
  - **Trust & Moderation:** Real-time abuse and incident resolution console.

### 2. Instagram-Style Deduplicated Moderation Console
- **Powered by:** `MiloModerationService`
- **Deduplication Engine:**
  - Multiple reports filed by different attendees against the same event, post, comment, or user profile are automatically clustered into a single incident card.
  - Badge highlights: `"🚨 4 Users Reported: Ananya, Rohan, Neha +more"`.
  - Severity automatically escalates to `"High (Critical)"` when report threshold is reached.
- **Decisive One-Click Action:**
  - `"Suspend & Block 🚫"`: Instantly marks the target as restricted, terminates active sessions, and records audit logs.
  - `"Dismiss"`: Resolves report when claims are found invalid without penalizing the user.
- **Target Category Tagging:** Clear visual pills for `EVENT`, `POST`, `COMMENT`, and `USER`.

---

## Future Roadmap

- [ ] **Phase 2 — Automated Image Vision Screening:** Server-side Google Cloud Vision / Gemini Flash filtering for explicit images uploaded to stories.
- [ ] **Phase 3 — Automated Chargeback & Dispute Handler:** Webhook sync with Razorpay/PayU for automated dispute resolution.
- [ ] **Phase 4 — Role-Based Superadmin Permission Sub-levels:** Junior moderator vs. financial auditor permission matrix.
