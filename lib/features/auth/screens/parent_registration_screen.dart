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

/// Parent Registration — 5 step flow.
class ParentRegistrationScreen extends ConsumerStatefulWidget {
  const ParentRegistrationScreen({super.key});

  @override
  ConsumerState<ParentRegistrationScreen> createState() => _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends ConsumerState<ParentRegistrationScreen> {
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
  DateTime? _dob;
  final _phoneController = TextEditingController();

  // Step 3 — Location
  final _cityController = TextEditingController();
  String? _country;
  final List<String> _countries = ['Pakistan', 'India', 'Bangladesh', 'Afghanistan', 'Other'];

  // Step 4 — Photo
  File? _photoFile;
  String? _photoUrl;

  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < 4 && _formKeys[_currentStep].currentState?.validate() != true) return;

    if (_currentStep == 0) {
      setState(() => _isLoading = true);
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
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

    if (_currentStep < 4) {
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
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
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
        role: 'parent',
        name: _nameController.text.trim(),
        gender: _gender,
        dob: _dob,
        phone: _phoneController.text.trim(),
        profilePhotoUrl: _photoUrl,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        city: _cityController.text.trim(),
        country: _country,
      );

      await firestoreService.setUser(user);
      if (mounted) context.go(Routes.parentDashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  String _getAuthError(String error) {
    if (error.contains('email-already-in-use')) return 'Email already registered.';
    if (error.contains('weak-password')) return 'Password is too weak.';
    return 'Registration failed.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: _currentStep > 0
            ? IconButton(icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary), onPressed: _previousStep)
            : IconButton(icon: const Icon(Icons.close, color: HearTechColors.textPrimary), onPressed: () => context.go(Routes.parentLogin)),
        title: Text('Parent Registration', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: StepIndicator(totalSteps: 5, currentStep: _currentStep),
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
      case 2: return _buildLocationStep();
      case 3: return _buildPhotoStep();
      case 4: return _buildReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildAuthStep() {
    return Form(key: _formKeys[0], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Your Account', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 1 of 5 — Authentication', style: HearTechTextStyles.caption()),
        const SizedBox(height: 32),
        HearTechInputField(controller: _emailController, label: 'Email', prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : (!v.contains('@') ? 'Invalid email' : null)),
        const SizedBox(height: 16),
        HearTechInputField(controller: _passwordController, label: 'Password', prefixIcon: Icons.lock_outline,
          obscureText: _obscurePassword,
          suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
          validator: (v) => (v != null && v.length < 6) ? 'Min 6 characters' : ((v == null || v.isEmpty) ? 'Required' : null)),
        const SizedBox(height: 16),
        HearTechInputField(controller: _confirmPasswordController, label: 'Confirm Password', prefixIcon: Icons.lock_outline,
          obscureText: true, validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
        const SizedBox(height: 24),
        HearTechButton(label: 'Create Account', onPressed: _nextStep, isLoading: _isLoading),
        const SizedBox(height: 16),
        HearTechButton(label: 'Sign up with Google', onPressed: _signUpWithGoogle, isSecondary: true, icon: Icons.g_mobiledata),
      ],
    ));
  }

  Widget _buildPersonalStep() {
    return Form(key: _formKeys[1], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal Information', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 2 of 5', style: HearTechTextStyles.caption()),
        const SizedBox(height: 32),
        HearTechInputField(controller: _nameController, label: 'Full Name', prefixIcon: Icons.person_outline,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _gender, decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(Icons.wc)),
          items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _gender = v)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDob,
          child: AbsorbPointer(
            child: HearTechInputField(
              label: 'Date of Birth',
              prefixIcon: Icons.calendar_today_outlined,
              hint: _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : 'Tap to select',
              controller: TextEditingController(text: _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : ''),
            ),
          ),
        ),
        const SizedBox(height: 16),
        HearTechInputField(controller: _phoneController, label: 'Phone Number', prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone, hint: '+92 xxx xxxxxxx'),
        const SizedBox(height: 24),
        HearTechButton(label: 'Continue', onPressed: _nextStep),
      ],
    ));
  }

  Widget _buildLocationStep() {
    return Form(key: _formKeys[2], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 3 of 5', style: HearTechTextStyles.caption()),
        const SizedBox(height: 32),
        HearTechInputField(controller: _cityController, label: 'City', prefixIcon: Icons.location_city_outlined),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _country, decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.public)),
          items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _country = v)),
        const SizedBox(height: 24),
        HearTechButton(label: 'Continue', onPressed: _nextStep),
      ],
    ));
  }

  Widget _buildPhotoStep() {
    return Form(key: _formKeys[3], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile Photo', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 4 of 5 (Optional)', style: HearTechTextStyles.caption()),
        const SizedBox(height: 32),
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: CircleAvatar(radius: 60, backgroundColor: HearTechColors.paleTeal,
              backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
              child: _photoFile == null ? const Icon(Icons.camera_alt_outlined, size: 32, color: HearTechColors.deepTeal) : null),
          ),
        ),
        const SizedBox(height: 16),
        Center(child: TextButton(onPressed: _pickPhoto, child: Text('Choose Photo', style: HearTechTextStyles.body(color: HearTechColors.deepTeal)))),
        const SizedBox(height: 32),
        HearTechButton(label: 'Continue', onPressed: _nextStep),
        const SizedBox(height: 12),
        Center(child: TextButton(onPressed: _nextStep, child: Text('Skip for now', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)))),
      ],
    ));
  }

  Widget _buildReviewStep() {
    return Form(key: _formKeys[4], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Create', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 5 of 5', style: HearTechTextStyles.caption()),
        const SizedBox(height: 24),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _r('Name', _nameController.text),
            _r('Gender', _gender ?? '-'),
            _r('DOB', _dob != null ? '${_dob!.day}/${_dob!.month}/${_dob!.year}' : '-'),
            _r('Phone', _phoneController.text.isNotEmpty ? _phoneController.text : '-'),
            _r('City', _cityController.text.isNotEmpty ? _cityController.text : '-'),
            _r('Country', _country ?? '-'),
          ]),
        ),
        const SizedBox(height: 24),
        HearTechButton(label: 'Create Profile', onPressed: _nextStep, isLoading: _isLoading),
      ],
    ));
  }

  Widget _r(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: HearTechTextStyles.caption())),
      Expanded(child: Text(value, style: HearTechTextStyles.body())),
    ]),
  );
}
