import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'role_selection_screen.dart'; // We will create this next

void main() async {
  // 1. Initialize Flutter & Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Run the App
  runApp(const HearTechApp());
}

class HearTechApp extends StatelessWidget {
  const HearTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HearTech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.bgOffWhite,
        useMaterial3: true,
        primaryColor: AppTheme.primaryTeal,
      ),
      // Start the app at the Role Selection Screen
      home: const RoleSelectionScreen(),
    );
  }
}
