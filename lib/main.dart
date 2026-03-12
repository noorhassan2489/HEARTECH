import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/notification_service.dart';

void main() async {
  // 1. Initialize Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Push Notifications
  await NotificationService().init();

  // 3. Run App wrapped in Riverpod ProviderScope
  runApp(const ProviderScope(child: HearTechApp()));
}

class HearTechApp extends StatelessWidget {
  const HearTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HearTech',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData, // Using the full design system
      initialRoute: AppRouter.splash, // Start at splash screen
      onGenerateRoute: AppRouter.generateRoute, // Centralized routing
    );
  }
}
