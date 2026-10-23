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
