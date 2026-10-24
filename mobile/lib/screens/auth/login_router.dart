import 'package:flutter/material.dart';
import '../../main.dart';
import '../../services/milo_session_service.dart';
import '../organizer/organizer_dashboard_screen.dart';

/// Central role → screen routing so splash, login and profile setup
/// all agree on where each role lands.
///
/// Android app is customer-first. Organizers land on their read-only
/// dashboard, while promoters/influencers, staff and admins use the same
/// customer shell and reach their work from Profile.
class LoginRouter {
 static Widget targetForRole(MiloRole? role) {
 switch (role) {
 case MiloRole.organizer:
 return const OrganizerDashboardScreen();
 case MiloRole.promoter:
 case MiloRole.staff:
 case MiloRole.admin:
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
