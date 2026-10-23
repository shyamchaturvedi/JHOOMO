# JHOOMO / Milo - Full Audit & Fix Plan

Date: 2026-10-23
Status: Plan only. No application code changed yet.
Scope: Mobile Flutter app, Firebase Functions, Firestore/Storage rules, admin-web, web landing, legacy scripts.

---

## 1. Goal

- App ko secure, error-free aur production-ready banana.
- Broken / unused / fake flows remove karna.
- Community ko event-focused banana:
  - Customer sirf like, comment, share, report/block kar sakta hai.
  - Customer post nahi bana sakta.
  - Organizer event updates post kar sakta hai.
  - Promoter / Influencer promo aur collab posts kar sakta hai.
  - Artist / Sponsor sirf admin-granted permission ke saath post kar sakte hain.
- Payments, auth, roles aur data flows ko backend se verify karna.

---

## 2. Critical Findings (P0 - release se pehle fix)

| # | Issue | Location | Risk |
|---|---|---|---|
| 1 | Neon DB credentials hardcoded | `server.js:10` | Database compromise |
| 2 | Vercel OIDC token local file me | `web/.env.local` | Account/project takeover |
| 3 | Payment bypass possible | `mobile/lib/services/milo_test_gateway.dart:20`, `mobile/lib/services/milo_razorpay_service.dart:12`, `mobile/lib/widgets/milo_bms_payment_sheet.dart:130` | Free ticket without real payment |
| 4 | Community posts backend me exist nahi | `firestore.rules`, `functions/src/index.ts` | No security, no persistence |
| 5 | Customer community post kar sakta hai | `mobile/lib/screens/community/single_community_hub_screen.dart:381,607` | Requirement violation |
| 6 | Profile save rules se mismatch | `mobile/lib/services/milo_auth_service.dart:159` vs `firestore.rules:69` | Profile save fail |
| 7 | Client-side role escalation | `mobile/lib/services/milo_auth_service.dart:182`, `mobile/lib/screens/auth/profile_setup_screen.dart:360`, `mobile/lib/screens/promoter/become_influencer_promoter_screen.dart:73` | Anyone can become organizer/promoter/admin in UI |
| 8 | Chat media sab signed-in users read kar sakte hain | `storage.rules` chat block | Private media leak |
| 9 | Admin allowlist kaam nahi karta | `mobile/lib/services/milo_auth_service.dart:214` | Admin flow broken |
| 10 | Client-side demo seeding rules se blocked | `mobile/lib/services/milo_db_service.dart:26-82` | Real data kabhi seed nahi hota |
| 11 | Organizer event save local MockData me | `mobile/lib/screens/organizer/create_event_screen.dart:795` | Event server par nahi jaata |
| 12 | Test gateway production me enabled | `mobile/lib/services/milo_test_gateway.dart:20` | Free bookings |

---

## 3. Other Important Findings (P1)

- `milo_db_service.dart:169` me `organizer_uid` use ho raha hai, jabki backend schema `organizerId` use karta hai.
- `getUserBookings` collection query me `userId` filter nahi hai; rules ke saath query fail ho sakti hai.
- Organizer create event server fail hone par silently local MockData me save karta hai.
- `PaymentApprovalService` demo data seed karta hai aur `autoConfirm` se ticket confirm karta hai.
- `milo_auth_service.dart` me `saveProfile` client se `phone`, `age`, `role`, `discoverable` likhta hai - rules allow nahi karte.
- Splash par stale local session restore ho sakta hai agar Firestore profile missing ho.
- `become_influencer_promoter_screen.dart` sirf local session role badal kar promoter bana deta hai.
- `list_your_show_screen.dart` bina KYC ke organizer role de deta hai.
- `profile_setup_screen.dart` me fake prefilled data hai (`Sahil Kumar`, `9876543210`).
- Admin allowlist `milo_config/admins` client se read hota hai, lekin rules me ye collection allowed nahi hai.
- `milo_db_service.dart` default admin phones seed karta hai, jo security risk hai.
- Android 13+ ke liye `POST_NOTIFICATIONS` permission manifest me missing hai.
- `storage.rules` me chat media aur support attachments ki read access zyada broad hai.
- Admin-web inactive admin ko block nahi karta; per-page level guard nahi hai.
- `mobile/test/widget_test.dart` me hardcoded super admin email aur demo-data expectations hain.
- `mobile/lib/services/firestore_service.dart` unused hai.
- `mobile/lib/organizer_app/` me 10 duplicate screens hain jo `screens/organizer/` se duplicate hain.
- `milo_side_drawer.dart:111-114` me dono branches same screen par jaati hain.
- Community share button sirf fake snackbar dikhata hai, actual share nahi karta.
- Community collab "Connect" button fake snackbar dikhata hai.
- Community event tag galat event par ja sakta hai (`MockData.first` fallback).
- `screens/community/ROADMAP.md` me stories/follow jaise features likhe hain jo actually implemented nahi hain.
- `MiloRazorpayService` client-side checkout karta hai aur success callback ko trust karta hai.
- `server.js` ke saare API routes unauthenticated hain (events create, bookings, users, admin payouts).

---

## 4. Community - Required Behavior

| Role | Create Post | Like | Comment | Share | Report/Block |
|---|---|---|---|---|---|
| Customer / Attendee | No | Yes | Yes | Yes | Yes |
| Organizer | Yes, only own event updates | Yes | Yes | Yes | Yes |
| Promoter / Influencer | Yes, promo/collab posts | Yes | Yes | Yes | Yes |
| Artist / Sponsor | Only with admin-granted `communityPoster` claim | Yes | Yes | Yes | Yes |
| Admin | Yes + moderation | Yes | Yes | Yes | Yes |

### UI Rules

- `+` create-post button sirf allowed roles ko dikhega.
- Customer create-post modal open nahi kar payega; read-only info message milega.
- Role selector me se `ATTENDEE` option remove.
- `ATTENDEE` filter tab remove.
- Attendee sample posts (jaise carpool post) remove.
- Post author name, avatar, role badge server se aayenge. Client fake badge nahi bhej payega.
- Event tag click real `eventId` se event kholega. `MockData.first` fallback remove.
- Share actual `share_plus` + deep link se hoga.
- Collab "Connect" button real connection request se wire hoga, warna remove.
- Likes, comments, shares persist honge.
- Report/Block server-side report karega.
- Blocked users ke posts/comments hide honge.
- Loading, empty aur error states add honge.

### Backend Design

New collections:

- `communityPosts/{postId}`
- `communityPosts/{postId}/comments/{commentId}`
- `communityPosts/{postId}/likes/{uid}`

New callables:

- `createCommunityPost`
- `updateCommunityPost`
- `deleteCommunityPost`
- `toggleCommunityLike`
- `addCommunityComment`
- `deleteCommunityComment`
- `shareCommunityPost`

Rules:

- Direct client writes: false.
- All mutations callables se.
- Counts transactions me update honge.
- Server-side validation:
  - Allowed role claim
  - Organizer event ownership
  - Text length
  - Profanity check
  - Media URL validation
  - Rate limit
  - Blocked user check

Indexes:

- `eventId + createdAt`
- `authorRole + createdAt`

---

## 5. Phase-wise Implementation

### Phase 0 - Secrets & Repo Cleanup

- [ ] Neon DB password rotate karo.
- [ ] Vercel OIDC token revoke karo.
- [ ] `server.js` delete karo.
- [ ] `migrate_neon.js` delete karo.
- [ ] `inject_event_report.js` delete karo.
- [ ] `inject_event_report2.js` delete karo.
- [ ] `inject_follow_btn.js` delete karo.
- [ ] `patch_overflows.js` delete karo.
- [ ] `patch_tickets.js` delete karo.
- [ ] Root `package.json` se `express`, `pg`, `cors` remove karo.
- [ ] `web/.env.local` delete karo.
- [ ] `.env.example` add karo.
- [ ] Debug logs delete karo:
  - `build_release.log`
  - `firestore-debug.log`
  - `database-debug.log`
- [ ] Git history me credentials hain; rotate ke baad optional `git filter-repo` se purge karo.

### Phase 1 - Auth, Roles & Profile Fix

- [ ] Mobile me `bootstrapUser` + `completeProfile` callables use karo.
- [ ] `saveProfile` direct Firestore write hatao.
- [ ] Profile schema align karo:
  - `displayName`
  - `dob`
  - `gender`
  - `cityId`
  - `interests`
  - `consents`
- [ ] Purane `name`, `age`, `role`, `phone` client writes remove karo.
- [ ] Profile setup se fake prefilled data remove karo.
- [ ] Role self-selection remove karo:
  - Customer default.
  - Organizer via KYC.
  - Promoter via `becomePromoter` application.
  - Staff via invite/passcode.
  - Admin via server claims only.
- [ ] `upgradeRole()` client write hatao.
- [ ] `switchRole()` ko privilege grant ke liye use mat karo.
- [ ] Splash par Firebase user + profile validate karo.
- [ ] Fail hone par stale session clear karo.
- [ ] Logout par secure storage + FCM token clear karo.
- [ ] `firestore.rules` users allowlist ko actual schema se match karo.
- [ ] `milo_config/admins` client read hatao.
- [ ] Admin access custom claims se enforce karo.

### Phase 2 - Community

- [ ] `CommunityPost` model me `fromMap` / `toMap` add karo.
- [ ] `CommunityComment` model me serialization add karo.
- [ ] Backend callables implement karo.
- [ ] Firestore rules add karo.
- [ ] Firestore indexes add karo.
- [ ] `single_community_hub_screen.dart` rewrite karo:
  - Role-gated create button/modal.
  - Attendee posting remove.
  - Attendee sample content remove.
  - Real service use, MockData remove.
  - Real share.
  - Real event link.
  - Real collab request.
  - Loading/empty/error states.
- [ ] Server-side profanity + rate limit + report/block.
- [ ] `screens/community/ROADMAP.md` actual implementation se update karo.

### Phase 3 - Payments & Booking Security

- [ ] Test gateway ko release mode me disable/remove karo.
- [ ] Test gateway sirf debug/demo flag ke peeche rakho.
- [ ] Razorpay client `onSuccess` ko source of truth mat banao.
- [ ] `createBooking` callable se server order create karo.
- [ ] Payment webhook verify hone ke baad hi ticket confirm karo.
- [ ] `PaymentApprovalService` auto-confirm/demo path production se hatao.
- [ ] Refund, ticket QR, cancel - sab existing callables se wire karo.
- [ ] Idempotency add karo.
- [ ] Amount server-side verify karo.

### Phase 4 - Events / Organizer / Promoter Flows

- [ ] `milo_db_service.dart` client seeding remove karo.
- [ ] Admin script/emulator se data seed karo.
- [ ] `organizer_uid` vs `organizerId` mismatch fix karo.
- [ ] Events list/detail/search existing callables se wire karo:
  - `listEvents`
  - `searchEvents`
  - `getEventDetails`
- [ ] Event create/edit existing callables se wire karo:
  - `saveEventDraft`
  - `submitEventForReview`
- [ ] `MockData.events.insert` remove karo.
- [ ] Staff flows existing callables se wire karo:
  - `createStaffPasscode`
  - `staffLogin`
  - `gateCheckIn`
- [ ] Local staff service fallback hatao.
- [ ] Organizer "List Your Show" instant upgrade ki jagah KYC onboarding.
- [ ] Promoter local registration ki jagah real application/approval.
- [ ] Duplicate `organizer_app/` screens delete karo.
- [ ] Canonical rakho `screens/organizer/`.
- [ ] Side drawer same-branch ternary fix karo.

### Phase 5 - Backend Rules & Storage Hardening

- [ ] `storage.rules` chat media sirf chat members ko.
- [ ] Support attachments sirf ticket owner/admin ko.
- [ ] Community rules add karo.
- [ ] Users/roles/consent fields server-only.
- [ ] Admin-web inactive admin block karo.
- [ ] Admin-web per-page `can(level)` guard add karo.
- [ ] Admin-web Firestore error handling improve karo.
- [ ] Legacy unauthenticated API endpoints remove karo.

### Phase 6 - Dead Code / Wrong Flow Removal

Remove:

- `mobile/lib/services/firestore_service.dart` (unused).
- `mobile/lib/organizer_app/` duplicate screens.
- Production `MockData` paths (sirf tests/demo flag me).
- Hardcoded super admin email test.
- Hardcoded admin phone numbers.
- Fake "saved on this device only" event flow.
- Fake share snackbar.
- Fake collab snackbar.
- Stale ROADMAP claims.
- Unused imports.
- Duplicate services.
- Test gateway production UI.

### Phase 7 - Quality Gates

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `flutter build appbundle --release`
- [ ] `cd functions; npm run typecheck`
- [ ] `cd functions; npm run build`
- [ ] `cd admin-web; npm run build`
- [ ] Firebase emulator rules tests:
  - Customer post denied.
  - Organizer own event update allowed.
  - Organizer other event update denied.
  - Promoter post allowed.
  - Customer like/comment/share allowed.
  - Blocked user comment denied.
  - Direct client write to counts denied.
- [ ] Manual smoke test:
  - Login
  - Profile save
  - Event booking
  - Payment verification
  - Ticket QR
  - Community customer read-only
  - Organizer/promoter post
  - Report/block
  - Logout
  - Deep link

---

## 6. Files To Touch First

- `mobile/lib/screens/community/single_community_hub_screen.dart`
- `mobile/lib/models/models.dart`
- `mobile/lib/services/milo_auth_service.dart`
- `mobile/lib/screens/auth/profile_setup_screen.dart`
- `mobile/lib/screens/promoter/become_influencer_promoter_screen.dart`
- `mobile/lib/screens/organizer/list_your_show_screen.dart`
- `mobile/lib/screens/organizer/create_event_screen.dart`
- `mobile/lib/services/milo_db_service.dart`
- `mobile/lib/services/payment_approval_service.dart`
- `mobile/lib/widgets/milo_bms_payment_sheet.dart`
- `firestore.rules`
- `storage.rules`
- `firestore.indexes.json`
- `functions/src/index.ts`
- `functions/src/social/community.ts` (new)
- `admin-web/src/auth/AuthProvider.tsx`
- `admin-web/src/App.tsx`

Delete:

- `server.js`
- `web/.env.local`
- `mobile/lib/organizer_app/`
- `migrate_neon.js`
- `inject_event_report.js`
- `inject_event_report2.js`
- `inject_follow_btn.js`
- `patch_overflows.js`
- `patch_tickets.js`

---

## 7. Decisions / Assumptions

1. Community backend: real Firestore + callables, local mock nahi.
2. Artist/Sponsor posting: admin-granted `communityPoster` claim se.
3. Share link: `$webBaseUrl/community/{postId}` + event deep link fallback.
4. Organizer screens: `screens/organizer/` canonical, `organizer_app/` delete.
5. Mock data: sirf `kDebugMode` / demo build me, release me real backend.
6. Payments: server order + webhook verification mandatory.
7. Roles: server-managed only; client role selection sirf customer onboarding ke liye.

---

## 8. Execution Order

1. Phase 0 - secrets cleanup
2. Phase 1 - auth/roles/profile
3. Phase 3 - payments (security)
4. Phase 2 - community permissions
5. Phase 4 - events/organizer/promoter
6. Phase 5 - rules/storage/admin-web
7. Phase 6 - dead code removal
8. Phase 7 - tests/build/verification

Har phase ke baad `flutter analyze`, relevant build/typecheck aur smoke test run hoga.
