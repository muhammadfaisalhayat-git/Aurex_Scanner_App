import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'services/erp_service.dart';
import 'services/locale_provider.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite for Desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Enterprise initialization
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization skipped or failed: $e");
  }

  runApp(const AurexApp());
}

class AurexApp extends StatelessWidget {
  const AurexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (_) => FirebaseService()),
        Provider(create: (_) => ErpService()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) => MaterialApp(
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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', ''),
            Locale('en', ''),
          ],
          locale: localeProvider.locale,
          home: const LoginScreen(),
        ),
      ),
    );
  }
}
