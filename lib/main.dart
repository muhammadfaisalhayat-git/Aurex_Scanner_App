import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'services/firebase_service.dart';
import 'services/locale_provider.dart';
import 'services/learning_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'screens/login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aurex Scanner',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      locale: localeProvider.locale,
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
    );
  }
}
