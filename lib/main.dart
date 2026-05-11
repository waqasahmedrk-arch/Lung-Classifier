import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LungScan AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
// ── App Theme ─────────────────────────────────────────────────────────────────

class AppTheme {
  // Brand colors
  static const Color primary = Color(0xFF00D4FF);       // Cyan
  static const Color secondary = Color(0xFF7B2FFF);     // Purple
  static const Color surface = Color(0xFF0D1B2A);       // Deep navy
  static const Color cardBg = Color(0xFF112233);        // Card navy
  static const Color cardBorder = Color(0xFF1E3A5F);    // Subtle border

  // Severity palette
  static const Color colorNormal = Color(0xFF00E676);
  static const Color colorModerate = Color(0xFFFFAB00);
  static const Color colorHigh = Color(0xFFFF6D00);
  static const Color colorCritical = Color(0xFFFF1744);

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
    ),
    fontFamily: 'Roboto',
  );
}
