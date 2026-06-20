import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'services/locale_provider.dart';
import 'services/theme_provider.dart';
import 'services/learning_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'l10n/app_localizations.dart';
// import 'firebase_options.dart'; // Commented out until generated

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  // Note: On Android, Firebase can initialize using google-services.json alone.
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Initialize Self-Learning AI
  await LearningService().init();

  // 3. Initialize Notifications & Background Tasks
  await NotificationService().init();
  BackgroundService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => FirebaseService()),
      ],
      child: const AurexApp(),
    ),
  );
}

class AurexApp extends StatelessWidget {
  const AurexApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aurex Scanner',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
          primary: const Color(0xFF388E3C),
          secondary: const Color(0xFF2E7D32),
          surface: Colors.white,
          background: const Color(0xFFF5F5F5),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF388E3C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
          primary: const Color(0xFF4CAF50),
          secondary: const Color(0xFF81C784),
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
          onSurface: Colors.white,
          onBackground: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      themeMode: themeProvider.themeMode,
      locale: localeProvider.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const LoginScreen(),
    );
  }
}
