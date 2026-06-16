import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/services/offline_service.dart';
import 'package:heartech/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive for offline caching
  await OfflineService.initialize();

  // OneSignal — push alerts + tap-to-navigate (handler wired in HearTechApp)
  await NotificationService.initialize();

  runApp(const ProviderScope(child: HearTechApp()));
}

class HearTechApp extends ConsumerStatefulWidget {
  const HearTechApp({super.key});

  @override
  ConsumerState<HearTechApp> createState() => _HearTechAppState();
}

class _HearTechAppState extends ConsumerState<HearTechApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final router = ref.read(routerProvider);
      NotificationService.setNavigationHandler((route) {
        router.push(route);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'HearTech',
      debugShowCheckedModeBanner: false,
      theme: HearTechTheme.lightTheme,
      routerConfig: router,
    );
  }
}
