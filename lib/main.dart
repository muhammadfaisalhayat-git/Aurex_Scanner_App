import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'services/erp_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enterprise initialization
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase connection deferred: $e");
  }

  runApp(const AurexApp());
}

class AurexApp extends StatelessWidget {
  const AurexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => FirebaseService()),
        Provider(create: (_) => ErpService()), // Global ERP Integration
      ],
      child: MaterialApp(
        title: 'Aurex Scanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF5E7D6A),
            primary: const Color(0xFF5E7D6A),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Color(0xFF5E7D6A),
            foregroundColor: Colors.white,
          ),
        ),
        // Built-in English & Arabic Support
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
          Locale('ar', ''),
        ],
        home: const LoginScreen(),
      ),
    );
  }
}
