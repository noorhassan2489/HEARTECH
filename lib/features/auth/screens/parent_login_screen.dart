import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';

/// Parent Login Screen
class ParentLoginScreen extends ConsumerStatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  ConsumerState<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends ConsumerState<ParentLoginScreen> {
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
      debugPrint('[HearTech] Parent login: starting sign in...');
      final authService = ref.read(firebaseAuthServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      debugPrint('[HearTech] Parent login: Firebase auth succeeded');

      if (!mounted) return;

      final user = authService.currentUser;
      if (user == null) {
        debugPrint('[HearTech] Parent login: currentUser is null after sign in!');
        return;
      }

      debugPrint('[HearTech] Parent login: uid=${user.uid}, fetching Firestore profile...');
      final firestoreService = ref.read(firestoreServiceProvider);
      final profile = await firestoreService.getUser(user.uid);

      if (!mounted) return;

      if (profile == null) {
        // Profile doesn't exist in Firestore yet — still go to dashboard
        // The dashboard handles empty state gracefully
        debugPrint('[HearTech] Parent login: no Firestore profile, going to dashboard anyway');
        context.go(Routes.parentDashboard);
        return;
      }

      debugPrint('[HearTech] Parent login: profile found, role=${profile.role}');

      if (profile.role != 'parent') {
        await authService.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('This account is registered as a ${profile.role}. Please use the ${profile.role} login.'),
              backgroundColor: HearTechColors.coralRed,
            ),
          );
        }
        return;
      }

      await authService.registerOneSignal(user.uid, profile.role);
      debugPrint('[HearTech] Parent login: navigating to parent dashboard');
      if (mounted) context.go(Routes.parentDashboard);
    } on FirebaseException catch (e) {
      debugPrint('[HearTech] Parent login: FirebaseException code=${e.code}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e.code)),
            backgroundColor: HearTechColors.coralRed,
          ),
        );
      }
    } catch (e) {
      debugPrint('[HearTech] Parent login: unexpected error: $e');
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
          if (profile.role != 'parent') {
            await authService.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('This account is registered as a ${profile.role}. Please use the ${profile.role} login.'),
                  backgroundColor: HearTechColors.coralRed,
                ),
              );
            }
            return;
          }
          await authService.registerOneSignal(result.user!.uid, profile.role);
          if (mounted) context.go(Routes.parentDashboard);
        } else if (mounted) {
          // No profile yet — go to dashboard anyway, it handles empty state
          debugPrint('[HearTech] Google login: no Firestore profile, going to dashboard');
          context.go(Routes.parentDashboard);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed'), backgroundColor: HearTechColors.coralRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final resetController = TextEditingController(text: _emailController.text.trim());
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HearTechColors.background,
        shape: RoundedRectangleBorder(borderRadius: HearTechDecorations.cardBorderRadius),
        title: Text('Reset Password', style: HearTechTextStyles.screenTitle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email to receive a password reset link.', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
            const SizedBox(height: 16),
            HearTechInputField(
              controller: resetController,
              label: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
          ),
          HearTechButton(
            label: 'Send',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (result == true) {
      final email = resetController.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid email address'), backgroundColor: HearTechColors.coralRed),
          );
        }
        return;
      }

      setState(() => _isLoading = true);
      try {
        await ref.read(firebaseAuthServiceProvider).sendPasswordResetEmail(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent!'), backgroundColor: HearTechColors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: HearTechColors.coralRed),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  String _getErrorMessage(String error) {
    // Handle FirebaseAuthException.code directly
    switch (error) {
      case 'user-not-found':
        return 'No account found with this email. Please create a profile first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
    }
    // Fallback: check error string for codes (from e.toString())
    if (error.contains('user-not-found')) return 'No account found with this email.';
    if (error.contains('wrong-password')) return 'Incorrect password. Please try again.';
    if (error.contains('invalid-credential')) return 'Incorrect email or password. Please try again.';
    if (error.contains('invalid-email')) return 'Please enter a valid email address.';
    if (error.contains('network-request-failed')) return 'No internet connection.';
    if (error.contains('too-many-requests')) return 'Too many attempts. Please wait.';
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
                Icon(Icons.family_restroom, size: 64, color: HearTechColors.deepTeal)
                    .animate().fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1),
                        duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text('Parent Portal', style: HearTechTextStyles.screenTitle()),
                const SizedBox(height: 8),
                Text('Sign in to manage your child\'s hearing health',
                    style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                const SizedBox(height: 40),

                HearTechInputField(
                  controller: _emailController, label: 'Email',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your email' : (!v.contains('@') ? 'Invalid email' : null),
                ),
                const SizedBox(height: 16),

                HearTechInputField(
                  controller: _passwordController, label: 'Password',
                  prefixIcon: Icons.lock_outline, obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  suffix: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                ),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text('Forgot Password?', style: HearTechTextStyles.caption(color: HearTechColors.deepTeal)),
                  ),
                ),
                const SizedBox(height: 16),

                HearTechButton(label: 'Sign In', onPressed: _signIn, isLoading: _isLoading),
                const SizedBox(height: 16),
                HearTechButton(label: 'Sign in with Google', onPressed: _signInWithGoogle, isSecondary: true, icon: Icons.g_mobiledata),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                    GestureDetector(
                      onTap: () => context.go(Routes.parentRegister),
                      child: Text('Create Account', style: HearTechTextStyles.body(color: HearTechColors.deepTeal).copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
