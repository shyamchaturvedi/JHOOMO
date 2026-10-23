import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/bms_list_your_show_portal_screen.dart';
import 'screens/bms_do_it_yourself_screen.dart';
import 'screens/organizer_dashboard_screen.dart';
import 'screens/create_event_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/manage_staff_roles_screen.dart';
import 'screens/settlements_screen.dart';
import 'screens/kyc_status_screen.dart';
import 'screens/gate_manual_lookup_screen.dart';
import '../../services/milo_session_service.dart';

/// Standalone entry point for Organizer App module.
/// Any developer working on Organizer App can launch this or route from main app.
class OrganizerAppEntry extends StatelessWidget {
  const OrganizerAppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // If user has already logged in or registered as organizer, take them straight to dashboard.
    // Otherwise open the BMS Do It Yourself List Your Show onboarding portal.
    final bool isOrganizer = MiloSessionService.currentRole == MiloRole.organizer;

    return isOrganizer
        ? const OrganizerDashboardScreen()
        : const BMSListYourShowPortalScreen();
  }
}

/// Standalone App Runner for independent developer testing.
/// Can be invoked with `runApp(const StandaloneOrganizerApp())` in any test/main driver.
class StandaloneOrganizerApp extends StatelessWidget {
  const StandaloneOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JHOOMO Organizer Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: GoogleFonts.inter().fontFamily,
      ),
      home: const OrganizerAppEntry(),
      routes: {
        '/dashboard': (_) => const OrganizerDashboardScreen(),
        '/create-event': (_) => const CreateEventScreen(),
        '/scanner': (_) => const QRScannerScreen(),
        '/staff': (_) => const ManageStaffRolesScreen(),
        '/settlements': (_) => const SettlementsScreen(),
        '/kyc': (_) => const KycStatusScreen(),
        '/gate-lookup': (_) => const GateManualLookupScreen(
              eventId: 'DEMO_EVENT',
              gateName: 'MAIN GATE',
            ),
        '/portal': (_) => const BMSListYourShowPortalScreen(),
        '/diy-signup': (_) => const BMSDoItYourselfScreen(),
      },
    );
  }
}
