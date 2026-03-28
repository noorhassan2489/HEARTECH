import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/models/user_model.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/heartech_input_field.dart';
import 'package:heartech/shared/widgets/step_indicator.dart';

/// HCW Registration — 6 step flow.
class HcwRegistrationScreen extends ConsumerStatefulWidget {
  const HcwRegistrationScreen({super.key});

  @override
  ConsumerState<HcwRegistrationScreen> createState() => _HcwRegistrationScreenState();
}

class _HcwRegistrationScreenState extends ConsumerState<HcwRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1 — Auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2 — Personal
  final _nameController = TextEditingController();
  String? _gender;
  String? _selectedTitle;
  final List<String> _titles = ['Dr.', 'Nurse', 'Audiologist', 'Health Worker', 'Other'];

  // Step 3 — Professional
  final _licenseController = TextEditingController();
  String? _specialization;
  final _hospitalController = TextEditingController();
  final _cityController = TextEditingController();
  final List<String> _specializations = [
    'Audiology', 'ENT', 'Pediatrics', 'Speech Pathology',
    'General Practice', 'Nursing', 'Other',
  ];

  // Step 4 — License upload
  File? _licenseFile;
  String? _licenseDocUrl;

  // Step 5 — Photo
  File? _photoFile;
  String? _photoUrl;

  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _licenseController.dispose();
    _hospitalController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < 5 && _formKeys[_currentStep].currentState?.validate() != true) return;

    if (_currentStep == 0) {
      // Create Firebase auth account
      setState(() => _isLoading = true);
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
        // Check if already signed in (e.g., Google sign-in from login page)
        if (authService.currentUser == null) {
          await authService.createAccountWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_getAuthError(e.toString())), backgroundColor: HearTechColors.coralRed),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      setState(() => _isLoading = false);
    }

    if (_currentStep < 5) {
      setState(() => _currentStep++);
    } else {
      await _submitProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      if (result != null) {
        _emailController.text = result.user?.email ?? '';
        _nameController.text = result.user?.displayName ?? '';
        setState(() => _currentStep = 1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-up failed'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickLicenseDoc() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _licenseFile = File(picked.path));
      // Upload to Cloudinary
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadImage(_licenseFile!, folder: 'heartech/licenses');
      if (url != null) setState(() => _licenseDocUrl = url);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (picked != null) {
      setState(() => _photoFile = File(picked.path));
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadImage(_photoFile!, folder: 'heartech/profiles');
      if (url != null) setState(() => _photoUrl = url);
    }
  }

  Future<void> _submitProfile() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);
      final uid = authService.uid!;

      final user = UserModel(
        uid: uid,
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : authService.currentUser?.email ?? '',
        role: 'hcw',
        name: _nameController.text.trim(),
        gender: _gender,
        profilePhotoUrl: _photoUrl,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isVerified: false,
        licenseNumber: _licenseController.text.trim(),
        licenseDocUrl: _licenseDocUrl,
        title: _selectedTitle,
        specialization: _specialization,
        hospitalName: _hospitalController.text.trim(),
        city: _cityController.text.trim(),
      );

      await firestoreService.setUser(user);

      if (mounted) context.go(Routes.hcwDashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  String _getAuthError(String error) {
    if (error.contains('email-already-in-use')) return 'Email already registered.';
    if (error.contains('weak-password')) return 'Password is too weak.';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
                onPressed: _previousStep,
              )
            : IconButton(
                icon: const Icon(Icons.close, color: HearTechColors.textPrimary),
                onPressed: () => context.go(Routes.hcwLogin),
              ),
        title: Text('HCW Registration', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: StepIndicator(totalSteps: 6, currentStep: _currentStep),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_currentStep) {
      case 0: return _buildAuthStep();
      case 1: return _buildPersonalStep();
      case 2: return _buildProfessionalStep();
      case 3: return _buildLicenseStep();
      case 4: return _buildPhotoStep();
      case 5: return _buildReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildAuthStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Your Account', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 1 of 6 — Authentication', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          HearTechInputField(
            controller: _emailController, label: 'Email', prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : (!v.contains('@') ? 'Invalid email' : null),
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: _passwordController, label: 'Password', prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffix: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v != null && v.length < 6) ? 'Min 6 characters' : ((v == null || v.isEmpty) ? 'Required' : null),
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: _confirmPasswordController, label: 'Confirm Password', prefixIcon: Icons.lock_outline,
            obscureText: true,
            validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          HearTechButton(label: 'Create Account', onPressed: _nextStep, isLoading: _isLoading),
          const SizedBox(height: 16),
          HearTechButton(label: 'Sign up with Google', onPressed: _signUpWithGoogle, isSecondary: true, icon: Icons.g_mobiledata),
        ],
      ),
    );
  }

  Widget _buildPersonalStep() {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 2 of 6', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          HearTechInputField(
            controller: _nameController, label: 'Full Name', prefixIcon: Icons.person_outline,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender, decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
            items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _gender = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedTitle, decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.badge_outlined)),
            items: _titles.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _selectedTitle = v),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          HearTechButton(label: 'Continue', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildProfessionalStep() {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Professional Details', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 3 of 6', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          HearTechInputField(
            controller: _licenseController, label: 'License Number', prefixIcon: Icons.badge,
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _specialization,
            decoration: const InputDecoration(labelText: 'Specialization', prefixIcon: Icon(Icons.local_hospital_outlined)),
            items: _specializations.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _specialization = v),
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: _hospitalController, label: 'Hospital / Clinic Name', prefixIcon: Icons.business_outlined,
          ),
          const SizedBox(height: 16),
          HearTechInputField(
            controller: _cityController, label: 'City', prefixIcon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 24),
          HearTechButton(label: 'Continue', onPressed: _nextStep),
        ],
      ),
    );
  }

  Widget _buildLicenseStep() {
    return Form(
      key: _formKeys[3],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upload License', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 4 of 6', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HearTechColors.warmOrange.withValues(alpha: 0.1),
              borderRadius: HearTechDecorations.cardBorderRadius,
              border: Border.all(color: HearTechColors.warmOrange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: HearTechColors.warmOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your account will be pending verification until your license is reviewed.',
                    style: HearTechTextStyles.caption(color: HearTechColors.warmOrange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Upload area
          GestureDetector(
            onTap: _pickLicenseDoc,
            child: Container(
              width: double.infinity, height: 180,
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
                border: Border.all(color: HearTechColors.divider, width: 2, strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: _licenseFile != null
                  ? ClipRRect(
                      borderRadius: HearTechDecorations.cardBorderRadius,
                      child: Image.file(_licenseFile!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined, size: 48, color: HearTechColors.deepTeal.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text('Tap to upload license document', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
                      ],
                    ),
            ),
          ),
          if (_licenseDocUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: HearTechColors.green, size: 16),
                const SizedBox(width: 4),
                Text('Uploaded successfully', style: HearTechTextStyles.caption(color: HearTechColors.green)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          HearTechButton(label: 'Continue', onPressed: _nextStep),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _nextStep,
              child: Text('Skip for now', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Form(
      key: _formKeys[4],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Photo', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 5 of 6 (Optional)', style: HearTechTextStyles.caption()),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: HearTechColors.paleTeal,
                backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                child: _photoFile == null
                    ? const Icon(Icons.camera_alt_outlined, size: 32, color: HearTechColors.deepTeal)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _pickPhoto,
              child: Text('Choose Photo', style: HearTechTextStyles.body(color: HearTechColors.deepTeal)),
            ),
          ),
          const SizedBox(height: 32),
          HearTechButton(label: 'Continue', onPressed: _nextStep),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _nextStep,
              child: Text('Skip for now', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return Form(
      key: _formKeys[5],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review & Submit', style: HearTechTextStyles.screenTitle()),
          const SizedBox(height: 8),
          Text('Step 6 of 6 — Confirm your details', style: HearTechTextStyles.caption()),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: HearTechDecorations.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_photoFile != null || _photoUrl != null) ...[
                  Center(child: CircleAvatar(radius: 40, backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null)),
                  const SizedBox(height: 16),
                ],
                _reviewRow('Name', _nameController.text),
                _reviewRow('Title', _selectedTitle ?? '-'),
                _reviewRow('Gender', _gender ?? '-'),
                _reviewRow('Email', _emailController.text.isNotEmpty ? _emailController.text : ref.read(firebaseAuthServiceProvider).currentUser?.email ?? ''),
                _reviewRow('License #', _licenseController.text.isNotEmpty ? _licenseController.text : '-'),
                _reviewRow('Specialization', _specialization ?? '-'),
                _reviewRow('Hospital', _hospitalController.text.isNotEmpty ? _hospitalController.text : '-'),
                _reviewRow('City', _cityController.text.isNotEmpty ? _cityController.text : '-'),
                _reviewRow('License Doc', _licenseDocUrl != null ? 'Uploaded ✓' : 'Not uploaded'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          HearTechButton(label: 'Create Profile', onPressed: _nextStep, isLoading: _isLoading),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: HearTechTextStyles.caption()),
          ),
          Expanded(
            child: Text(value, style: HearTechTextStyles.body()),
          ),
        ],
      ),
    );
  }
}
