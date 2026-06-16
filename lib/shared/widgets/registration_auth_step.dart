import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/utils/registration_flow.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';

/// Step 0 of registration — create account, continue same role, or wrong-role warning.
class RegistrationAuthStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscurePassword;
  final bool isLoading;
  final RegistrationAuthMode mode;
  final String currentRoleLabel;
  final String? pendingRoleLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onGooglePressed;
  final Future<void> Function() onUseDifferentAccount;
  final VoidCallback? onGoToPendingRegistration;
  final int totalSteps;

  const RegistrationAuthStep({
    super.key,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleObscurePassword,
    required this.isLoading,
    required this.mode,
    required this.currentRoleLabel,
    this.pendingRoleLabel,
    required this.onPrimaryPressed,
    required this.onGooglePressed,
    required this.onUseDifferentAccount,
    this.onGoToPendingRegistration,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case RegistrationAuthMode.continueProfile:
        return _buildContinueProfile();
      case RegistrationAuthMode.wrongRolePending:
        return _buildWrongRolePending();
      case RegistrationAuthMode.createAccount:
        return _buildCreateAccount();
    }
  }

  Widget _buildContinueProfile() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Continue $currentRoleLabel Registration',
            style: HearTechTextStyles.screenTitle(),
          ),
          const SizedBox(height: 8),
          Text(
            'Step 1 of $totalSteps — Account created',
            style: HearTechTextStyles.caption(),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HearTechColors.paleTeal,
              borderRadius: HearTechDecorations.cardBorderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in as', style: HearTechTextStyles.caption()),
                const SizedBox(height: 4),
                Text(
                  emailController.text.isNotEmpty
                      ? emailController.text
                      : 'Your account',
                  style: HearTechTextStyles.body(color: HearTechColors.deepTeal),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick up where you left off and finish your $currentRoleLabel profile.',
                  style: HearTechTextStyles.caption(
                    color: HearTechColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          HearTechButton(label: 'Continue $currentRoleLabel Profile', onPressed: onPrimaryPressed),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () async => onUseDifferentAccount(),
              child: Text(
                'Use a different email',
                style: HearTechTextStyles.body(color: HearTechColors.coralRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWrongRolePending() {
    final hasKnownPendingRole =
        pendingRoleLabel != null && onGoToPendingRegistration != null;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create $currentRoleLabel Account',
            style: HearTechTextStyles.screenTitle(),
          ),
          const SizedBox(height: 8),
          Text(
            'Step 1 of $totalSteps — Authentication',
            style: HearTechTextStyles.caption(),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HearTechColors.warmOrange.withValues(alpha: 0.1),
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(
                color: HearTechColors.warmOrange.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: HearTechColors.warmOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasKnownPendingRole
                            ? 'You have an unfinished $pendingRoleLabel registration'
                            : 'Another signup is already in progress on this device',
                        style: HearTechTextStyles.subtitle(
                          color: HearTechColors.warmOrange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasKnownPendingRole
                      ? 'Finish that profile first, or sign out to create a new $currentRoleLabel account with a different email.'
                      : 'Sign out to start a fresh $currentRoleLabel registration with email and password.',
                  style: HearTechTextStyles.caption(
                    color: HearTechColors.textSecondary,
                  ),
                ),
                if (emailController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Currently signed in as ${emailController.text}',
                    style: HearTechTextStyles.caption(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (hasKnownPendingRole) ...[
            HearTechButton(
              label: 'Continue $pendingRoleLabel Registration',
              onPressed: onGoToPendingRegistration!,
            ),
            const SizedBox(height: 12),
          ],
          HearTechButton(
            label: 'Use a different email',
            onPressed: () async => onUseDifferentAccount(),
            isSecondary: hasKnownPendingRole,
            backgroundColor: hasKnownPendingRole
                ? null
                : HearTechColors.coralRed.withValues(alpha: 0.1),
            textColor: hasKnownPendingRole ? null : HearTechColors.coralRed,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateAccount() {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your $currentRoleLabel Account',
            style: HearTechTextStyles.screenTitle(),
          ),
          const SizedBox(height: 8),
          Text(
            'Step 1 of $totalSteps — Authentication',
            style: HearTechTextStyles.caption(),
          ),
          const SizedBox(height: 32),
          HearTechInputField(
            controller: emailController,
            label: 'Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty)
                ? 'Required'
                : (!v.contains('@') ? 'Invalid email' : null),
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: passwordController,
            label: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: obscurePassword,
            suffix: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: onToggleObscurePassword,
            ),
            validator: (v) => (v != null && v.length < 6)
                ? 'Min 6 characters'
                : ((v == null || v.isEmpty) ? 'Required' : null),
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            validator: (v) =>
                v != passwordController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          HearTechButton(
            label: 'Create Account',
            onPressed: onPrimaryPressed,
            isLoading: isLoading,
          ),
          const SizedBox(height: 16),
          HearTechButton(
            label: 'Sign up with Google',
            onPressed: onGooglePressed,
            isSecondary: true,
            icon: Icons.g_mobiledata,
          ),
        ],
      ),
    );
  }
}
