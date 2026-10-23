# JHOOMO Organizer Studio Module (Developer Handoff)

Welcome to the **JHOOMO Organizer Studio** module! This dedicated folder contains everything needed to develop, run, test, and complete the Organizer and Event Host experience.

---

## 📁 Directory Structure

```
lib/organizer_app/
├── organizer_app.dart                # Standalone Entry Point & Route Definitions
├── README.md                         # Architecture, schema, and developer guide (this file)
└── screens/                          # Complete screens for Organizer workflow
    ├── bms_list_your_show_portal_screen.dart # BMS-style 4-step onboarding wizard
    ├── bms_do_it_yourself_screen.dart        # Self-serve DIY organizer registration
    ├── list_your_show_screen.dart            # Quick-activation show listing screen
    ├── organizer_dashboard_screen.dart       # Master Dashboard (Analytics, Revenue, Live Status)
    ├── create_event_screen.dart              # Multi-tier event creation with pass pricing
    ├── qr_scanner_screen.dart                # High-speed QR scanner for gate entry (mobile_scanner)
    ├── gate_manual_lookup_screen.dart        # Phone/Ticket ID manual search fallback
    ├── manage_staff_roles_screen.dart        # Team access delegation (Bouncer, Gate Scanner, Manager)
    ├── settlements_screen.dart               # T+1 payout breakdown, platform fee, UTR tracking
    └── kyc_status_screen.dart                # PAN, GSTIN & bank verification lifecycle
```

---

## 🚀 How to Run the Organizer App Standalone

During development, you don't need to navigate through the Customer App. You can run the Organizer Studio directly:

### Option A: Via Main App Entry (`main.dart`)
Replace `home` in `MaterialApp` with:
```dart
import 'package:milo/organizer_app/organizer_app.dart';

// ...
home: const StandaloneOrganizerApp(),
```

### Option B: Route from Within Customer App
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const OrganizerAppEntry()),
);
```

---

## 🧭 Flow & Screen Inventory

| # | Screen | Purpose |
|---|---|---|
| 1 | **BMSListYourShowPortalScreen** | Public landing page for event hosts with "List Your Show" CTA. |
| 2 | **BMSDoItYourselfScreen** | 4-step self-serve onboarding (Event Type, Expected Footfall, City, Contact). |
| 3 | **KycStatusScreen** | PAN / GST / Cancelled Cheque upload & verification status. |
| 4 | **OrganizerDashboardScreen** | Central Command Hub: Gross GMV, Real-time Tickets Sold, Live Gate check-in count, active event cards. |
| 5 | **CreateEventScreen** | Add show details, date/time, venue, poster image, and multiple ticket tiers (Early Bird, VIP, Couple). |
| 6 | **QRScannerScreen** | High-performance camera scanner for attendee tickets with anti-passback and duplicate prevention. |
| 7 | **GateManualLookupScreen** | Backup lookup by Attendee Phone Number, Ticket ID, or Order ID if camera fails. |
| 8 | **ManageStaffRolesScreen** | Invite gatekeepers and bouncers with role-based QR access PINs. |
| 9 | **SettlementsScreen** | Payout breakdown: Gross sales minus 5% platform fee, GST deduction, and UTR bank transfer tracking. |

---

## 🗄️ Backend / Firestore Dependencies

1. **`organizers` Collection**:
   - `uid`: User ID matching Firebase Auth.
   - `organizationName`: Business or agency name.
   - `kycStatus`: `'pending' | 'verified' | 'rejected'`.
   - `panNumber`, `gstin`, `bankAccountNumber`, `ifsc`.

2. **`events` Collection**:
   - `organizerId`: UID of the creator.
   - `title`, `description`, `venue`, `city`, `dateTime`.
   - `tiers`: Array of `{ name, price, totalSeats, soldCount }`.
   - `status`: `'draft' | 'published' | 'completed' | 'cancelled'`.

3. **`tickets` Collection**:
   - Scanned during gate entry via `QRScannerScreen`.
   - `status`: Updated from `'valid'` to `'used'` upon scan.
   - `scannedAt`: Timestamp.
   - `scannedByGate`: String name of gate.

4. **`settlements` Collection**:
   - Tracks T+1 payout batches, net payout amounts, and bank UTRs.

---

## 🛠️ State & Session

- Role is controlled via `MiloSessionService.currentRole` (`MiloRole.organizer`).
- Database helpers reside in `MiloDbService.instance`.
- Design tokens (colors, gradients, typography) reside in `lib/theme/milo_theme.dart`.

Happy building! 🚀
