# JHOOMO Organizer Hub — Screen Architecture & Roadmap

## Overview
The Organizer Portal provides an end-to-end command center for event hosts, festival directors, and venue managers to list shows, manage ticket inventory, scan gates, track promoter campaigns, and reconcile settlements.

---

## Active Implemented Architecture

### 1. Event Creation & DIY Wizard
- **Files:** `create_event_screen.dart`, `bms_do_it_yourself_screen.dart`, `list_your_show_screen.dart`, `bms_list_your_show_portal_screen.dart`
- Multi-tier ticket setup (Early Bird, Phase 1, VIP, Squad Pass).
- Commission setup for creators (₹ per ticket, auto-accept influencer requests toggle).
- Organizer agreement and tax compliance declaration.

### 2. Organizer Command Dashboard
- **File:** `organizer_dashboard_screen.dart`
- Real-time ticket sales velocity, gross revenue, check-in stats, and active promoter conversions.
- One-click launch of Event 1-Way Broadcast Channel (`HostBroadcastChannelScreen`).

### 3. Gate Entry & QR Scanner
- **Files:** `qr_scanner_screen.dart`, `gate_manual_lookup_screen.dart`, `manage_staff_roles_screen.dart`
- Instant offline-capable QR ticket scanning with duplicate scan prevention.
- Manual phone/booking ID lookup for attendees without working battery/screens.
- Role-based gate security staff assignments.

### 4. Settlements & Compliance
- **Files:** `settlements_screen.dart`, `kyc_status_screen.dart`
- Bank account verification and settlement reconciliation (5–7 working days post-event).
- Automated TDS and GST deduction breakdowns.

---

## Future Roadmap

- [ ] **Phase 2 — Multi-Day Festival RFID Wristband Sync:** NFC wristband top-up and cashless payments at food stalls.
- [ ] **Phase 3 — Dynamic Ticket Pricing Engine:** Automatic price surges based on velocity and remaining tier capacity.
- [ ] **Phase 4 — WhatsApp Broadcast Integration:** Official WhatsApp Business API broadcast notifications for critical venue changes.
