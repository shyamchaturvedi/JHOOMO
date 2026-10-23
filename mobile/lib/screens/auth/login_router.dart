import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/milo_session_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../organizer/organizer_dashboard_screen.dart';
import '../organizer/qr_scanner_screen.dart';
import '../promoter/promoter_dashboard_screen.dart';

/// Central role → screen routing so splash, login and profile setup
/// all agree on where each role lands.
class LoginRouter {
 static Widget targetForRole(MiloRole? role) {
 switch (role) {
 case MiloRole.organizer:
 return const OrganizerDashboardScreen();
 case MiloRole.promoter:
 return const PromoterDashboardScreen();
 case MiloRole.staff:
 return const QRScannerScreen();
 case MiloRole.admin:
 return const AdminDashboardScreen();
 case MiloRole.customer:
 case null:
 return const MainNavigationScreen();
 }
 }

 static void go(BuildContext context, MiloRole? role) {
 Navigator.pushAndRemoveUntil(
 context,
 MaterialPageRoute(builder: (_) => targetForRole(role)),
 (route) => false,
 );
 }
}
