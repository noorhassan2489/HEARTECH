import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/services/offline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Hive for offline caching
  await OfflineService.initialize();

  // Initialize OneSignal — uncomment when you have the App ID configured
  // await NotificationService.initialize();

  runApp(const ProviderScope(child: HearTechApp()));
}

class HearTechApp extends ConsumerWidget {
  const HearTechApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HearTech',
      debugShowCheckedModeBanner: false,
      theme: HearTechTheme.lightTheme,
      routerConfig: router,
    );
  }
}
