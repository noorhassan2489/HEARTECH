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
        String route;

        switch (role) {
          case 'parent':
            route = AppRouter.parentDashboard;
            break;
          case 'hcw':
            route = AppRouter.hcwDashboard;
            break;
          case 'teacher':
            route = AppRouter.teacherDashboard;
            break;
          default:
            route = AppRouter.roleSelect;
        }

        Navigator.of(context).pushNamedAndRemoveUntil(
          route,
          (route) => false, // Clear the entire nav stack
        );
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.roleSelect,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.roleSelect,
          (route) => false,
        );
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
