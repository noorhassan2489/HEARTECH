import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firestore_service.dart';

class FirstTimeLoginCheckScreen extends StatefulWidget {
  final String uid;

  const FirstTimeLoginCheckScreen({super.key, required this.uid});

  @override
  State<FirstTimeLoginCheckScreen> createState() => _FirstTimeLoginCheckScreenState();
}

class _FirstTimeLoginCheckScreenState extends State<FirstTimeLoginCheckScreen> {
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final doc = await _firestoreService.getUserProfile(widget.uid);
      if (!mounted) return;

      if (doc != null && doc.isNotEmpty) {
        // Profile exists, route based on role
        final role = doc['role'] as String?;

        switch (role) {
          case 'parent':
            Navigator.pushReplacementNamed(context, AppRouter.parentDashboard);
            break;
          case 'hcw':
            Navigator.pushReplacementNamed(context, AppRouter.hcwDashboard);
            break;
          case 'teacher':
            Navigator.pushReplacementNamed(context, AppRouter.teacherDashboard);
            break;
          default:
            Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
        }
      } else {
        // Profile does not exist yet. This usually means they signed in with Google
        // for the first time without creating an account first, or account creation was interrupted.
        // Send them to role selection.
        Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.roleSelect);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
