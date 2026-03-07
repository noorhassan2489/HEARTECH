import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HWLoginScreen extends StatefulWidget {
  const HWLoginScreen({super.key});

  @override
  State<HWLoginScreen> createState() => _HWLoginScreenState();
}

class _HWLoginScreenState extends State<HWLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.medical_services,
                size: 60,
                color: AppTheme.primaryTeal,
              ),
              const SizedBox(height: 24),
              Text("Healthcare Worker Portal", style: AppTheme.heading1),
              const SizedBox(height: 8),
              Text(
                "Sign in to access patient screenings and records.",
                style: AppTheme.subtitle,
              ),
              const SizedBox(height: 40),

              // Email Field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: AppTheme.inputDecoration(
                  "Email Address",
                  Icons.email_outlined,
                ),
              ),
              const SizedBox(height: 20),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: AppTheme.inputDecoration(
                  "Password",
                  Icons.lock_outline,
                ),
              ),
              const SizedBox(height: 40),

              // Login Button
              ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: () {
                  // TODO: Add Firebase Auth Logic Here
                  print("Login clicked");
                },
                child: const Text("Sign In"),
              ),
              const SizedBox(height: 20),

              // Create Account Link
              TextButton(
                onPressed: () {
                  // TODO: Navigate to HW Registration Screen
                },
                child: Text(
                  "Don't have an account? Create Professional Profile",
                  style: TextStyle(
                    color: AppTheme.primaryTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
