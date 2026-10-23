import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/milo_theme.dart';
import 'screens/home_screen.dart';
import 'screens/explore_events_screen.dart';
import 'screens/community/single_community_hub_screen.dart';
import 'screens/profile_safety_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/event_details_screen.dart';
import 'widgets/milo_side_drawer.dart';
import 'widgets/milo_shell_scope.dart';
import 'models/models.dart';
import 'services/milo_db_service.dart';
import 'services/milo_deep_link_service.dart';
import 'services/milo_wishlist_service.dart';
import 'services/milo_session_service.dart';
import 'services/milo_notification_service.dart';

void main() async {
 WidgetsFlutterBinding.ensureInitialized();

 // Global Error Protection to prevent Android App from Stopping/Crashing
 FlutterError.onError = (FlutterErrorDetails details) {
 FlutterError.presentError(details);
 debugPrint('Milo App Protected Error: ${details.exception}');
 };

 PlatformDispatcher.instance.onError = (error, stack) {
 debugPrint('Milo Async Uncaught Error: $error');
 return true; // Prevents crash
 };

 try {
 await Firebase.initializeApp();
    unawaited(MiloNotificationService.instance.init());
 } catch (e) {
 debugPrint("Firebase init note: $e");
 }
 unawaited(MiloDeepLinkService.instance.init());
 runApp(const MiloApp());
}

class MiloApp extends StatelessWidget {
 const MiloApp({super.key});

 @override
 Widget build(BuildContext context) {
 return MaterialApp(
 title: 'JHOOMO',
 debugShowCheckedModeBanner: false,
 theme: JhoomoTheme.lightTheme,
 home: const SplashScreen(),
 );
 }
}

class MainNavigationScreen extends StatefulWidget {
 const MainNavigationScreen({super.key});

 @override
 State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
 int _currentIndex = 0;
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

 void _onNavigate(int index) {
 setState(() => _currentIndex = index);
 }

 void _openDrawer() {
 _scaffoldKey.currentState?.openEndDrawer();
 }

 @override
 void initState() {
 super.initState();
 WidgetsBinding.instance.addPostFrameCallback((_) {
 MiloWishlistService.instance.load(MiloSessionService.currentUid);
 _handlePendingDeepLink();
 });
 }

 Future<void> _handlePendingDeepLink() async {
 final deepLinks = MiloDeepLinkService.instance;
 final eventId = deepLinks.takePendingEventId();
 final refCode = deepLinks.takePendingReferralCode();
 if (!mounted) return;

 if (eventId.isNotEmpty) {
 try {
 final events = await MiloDbService.instance.getEvents();
 EventModel? event;
 for (final e in events) {
 if (e.id == eventId) {
 event = e;
 break;
 }
 }
 final found = event;
 if (found != null && mounted) {
 Navigator.push(
 context,
 MaterialPageRoute(
 builder: (_) => EventDetailsScreen(event: found, initialPromoCode: refCode),
 ),
 );
 return;
 }
 } catch (e) {
 debugPrint('Deep link event lookup note: $e');
 }
 }

 if (refCode.isNotEmpty && mounted) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(
 content: Text(' Referral code $refCode saved — apply it while booking any event.'),
 ),
 );
 }
 }

 @override
 Widget build(BuildContext context) {
 final screens = [
 HomeScreen(onNavigateTab: _onNavigate, onOpenMenu: _openDrawer),
 const ExploreEventsScreen(),
 const SingleCommunityHubScreen(),
 const WishlistScreen(),
 const ProfileSafetyScreen(),
 ];

 return Scaffold(
 key: _scaffoldKey,
 backgroundColor: JhoomoTokens.surface,
 extendBody: true,
 endDrawer: MiloSideDrawer(onSelectTab: _onNavigate),
 body: MiloShellScope(
 openMenu: _openDrawer,
 goToTab: _onNavigate,
 child: IndexedStack(
 index: _currentIndex,
 children: screens,
 ),
 ),
 bottomNavigationBar: Container(
 decoration: BoxDecoration(
 color: Colors.white,
 boxShadow: [
 BoxShadow(
 color: Colors.black.withValues(alpha: 0.06),
 blurRadius: 16,
 offset: const Offset(0, -4),
 ),
 ],
 ),
 child: SafeArea(
 top: false,
 child: SizedBox(
 height: 64,
 child: Row(
 mainAxisAlignment: MainAxisAlignment.spaceAround,
 children: [
 _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
 _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, 'Explore'),
 // Center Community Action Button
 GestureDetector(
 onTap: () => _onNavigate(2),
 child: Container(
 width: 46,
 height: 46,
 decoration: BoxDecoration(
 gradient: JhoomoGradients.brandIcon,
 shape: BoxShape.circle,
 boxShadow: [
 BoxShadow(
 color: JhoomoTokens.primary.withValues(alpha: 0.35),
 blurRadius: 10,
 offset: const Offset(0, 4),
 ),
 ],
 ),
 child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
 ),
 ),
 _buildNavItem(3, Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'Saved'),
 _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
 ],
 ),
 ),
 ),
 ),
 );
 }

 Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
 final isSelected = _currentIndex == index;
 return GestureDetector(
 onTap: () => setState(() => _currentIndex = index),
 behavior: HitTestBehavior.opaque,
 child: Column(
 mainAxisSize: MainAxisSize.min,
 mainAxisAlignment: MainAxisAlignment.center,
 children: [
 Icon(
 isSelected ? activeIcon : icon,
 color: isSelected ? JhoomoColors.primary : JhoomoColors.textMuted,
 size: 24,
 ),
 const SizedBox(height: 3),
 Text(
 label,
 style: GoogleFonts.inter(
 fontSize: 11,
 fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
 color: isSelected ? JhoomoColors.primary : JhoomoColors.textMuted,
 ),
 ),
 ],
 ),
 );
 }
}
