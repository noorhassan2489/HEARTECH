import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';

/// HCW Login Screen
class HcwLoginScreen extends ConsumerStatefulWidget {
  const HcwLoginScreen({super.key});

  @override
  ConsumerState<HcwLoginScreen> createState() => _HcwLoginScreenState();
}

class _HcwLoginScreenState extends ConsumerState<HcwLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        // Check if user profile exists and route to dashboard
        final firestoreService = ref.read(firestoreServiceProvider);
        final user = authService.currentUser;
        if (user != null) {
          final profile = await firestoreService.getUser(user.uid);
          if (profile != null && mounted) {
            context.go(Routes.hcwDashboard);
          } else if (mounted) {
            // No profile — go to registration
            context.go(Routes.hcwRegister);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.toString())),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      if (result != null && mounted) {
        final firestoreService = ref.read(firestoreServiceProvider);
        final profile = await firestoreService.getUser(result.user!.uid);
        if (profile != null && mounted) {
          context.go(Routes.hcwDashboard);
        } else if (mounted) {
          context.go(Routes.hcwRegister);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: ${e.toString()}'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email first')),
      );
      return;
    }
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent!'),
            backgroundColor: HearTechColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password')) return 'Incorrect password.';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    if (error.contains('too-many-requests')) return 'Too many attempts. Try later.';
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Icon
                Icon(
                  Icons.medical_services_outlined,
                  size: 64,
                  color: HearTechColors.deepTeal,
                ).animate().fadeIn(duration: 300.ms).scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 400.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 16),
                Text(
                  'Healthcare Portal',
                  style: HearTechTextStyles.screenTitle(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to screen and manage patients',
                  style: HearTechTextStyles.body(
                    color: HearTechColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                // Email
                HearTechInputField(
                  controller: _emailController,
                  label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                HearTechInputField(
                  controller: _passwordController,
                  label: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: HearTechTextStyles.caption(
                        color: HearTechColors.deepTeal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign in button
                HearTechButton(
                  label: 'Sign In',
                  onPressed: _signIn,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),

                // Google sign in
                HearTechButton(
                  label: 'Sign in with Google',
                  onPressed: _signInWithGoogle,
                  isSecondary: true,
                  icon: Icons.g_mobiledata,
                ),
                const SizedBox(height: 24),

                // Create profile link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: HearTechTextStyles.body(
                        color: HearTechColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(Routes.hcwRegister),
                      child: Text(
                        'Create HCW Profile',
                        style: HearTechTextStyles.body(
                          color: HearTechColors.deepTeal,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Back to role select
                TextButton.icon(
                  onPressed: () => context.go(Routes.roleSelect),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Back to role selection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
