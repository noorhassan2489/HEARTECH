import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';

class TeacherLoginScreen extends StatefulWidget {
  const TeacherLoginScreen({super.key});

  @override
  State<TeacherLoginScreen> createState() => _TeacherLoginScreenState();
}

class _TeacherLoginScreenState extends State<TeacherLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (mounted) {
        final user = _authService.currentUser;
        if (user != null) {
          Navigator.pushReplacementNamed(
            context, AppRouter.authCheck,
            arguments: {'uid': user.uid},
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCred = await _authService.signInWithGoogle();
      if (userCred != null && mounted) {
        Navigator.pushReplacementNamed(
          context, AppRouter.authCheck,
          arguments: {'uid': userCred.user!.uid},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.school,
                size: 60,
                color: AppTheme.primaryTeal,
              ),
              const SizedBox(height: 24),
              Text("Teacher Portal", style: AppTheme.heading1),
              const SizedBox(height: 8),
              Text(
                "Sign in to access classroom hearing observations.",
                style: AppTheme.subtitle,
              ),
              const SizedBox(height: 40),

              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: AppTheme.inputDecoration("Email Address", Icons.email_outlined),
              ),
              const SizedBox(height: 20),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: AppTheme.inputDecoration("Password", Icons.lock_outline),
              ),
              
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text("Forgot Password?", style: TextStyle(color: AppTheme.primaryTeal)),
                ),
              ),
              const SizedBox(height: 24),

              // Login Button
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text("Sign In"),
              ),
              const SizedBox(height: 16),

              // Google Sign In Button
              OutlinedButton.icon(
                style: AppTheme.secondaryButton,
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: Image.asset('assets/images/google_logo.png', height: 24, errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 24)),
                label: const Text("Sign in with Google"),
              ),
              const SizedBox(height: 32),

              // Create Account Link
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRouter.teacherRegister),
                child: Text(
                  "Don't have an account? Create Teacher Profile",
                  style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
