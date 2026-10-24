import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/staff_auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/scanner_screen.dart';
import 'theme/scanner_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait orientation for scanner stability
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // System navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ScannerTokens.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final session = await StaffAuthService.instance.restoreSession();
  runApp(JhoomoScannerApp(initialSession: session));
}

class JhoomoScannerApp extends StatelessWidget {
  final StaffAuthSession? initialSession;

  const JhoomoScannerApp({super.key, this.initialSession});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JHOOMO Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: ScannerTokens.background,
        colorScheme: const ColorScheme.dark(
          primary: ScannerTokens.primary,
          secondary: ScannerTokens.orange,
          surface: ScannerTokens.surfaceCard,
        ),
      ),
      home: initialSession != null
          ? ScannerScreen(session: initialSession!)
          : const StaffLoginScreen(),
    );
  }
}
