import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Adding a short delay to show the HearTech branding
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // If user is already logged in, we check if they are first time or have a role
      // For now, let's route to authCheck so it can determine their dashboard
      Navigator.pushReplacementNamed(
        context, 
        AppRouter.authCheck, 
        arguments: {'uid': user.uid},
      );
    } else {
      // No user, go to role selection
      Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryTeal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Using a simple icon until we have the real logo asset
            const Icon(
              Icons.hearing,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'HEARTECH',
              style: AppTheme.heading1.copyWith(
                color: Colors.white,
                letterSpacing: 2.0,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
