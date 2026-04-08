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

/// Teacher Registration — 5 step flow.
class TeacherRegistrationScreen extends ConsumerStatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  ConsumerState<TeacherRegistrationScreen> createState() => _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends ConsumerState<TeacherRegistrationScreen> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _isUploading = false;

  // Step 1 — Auth
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  // Step 2 — Personal
  final _nameController = TextEditingController();
  String? _gender;

  // Step 3 — Professional
  final _schoolController = TextEditingController();
  final _cityController = TextEditingController();
  final _yearsController = TextEditingController();
  final Set<String> _selectedGrades = {};
  final List<String> _allGrades = [
    'Pre-K', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
    'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10', 'Grade 11', 'Grade 12',
  ];

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
    _schoolController.dispose();
    _cityController.dispose();
    _yearsController.dispose();
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

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (picked != null) {
      setState(() {
        _photoFile = File(picked.path);
        _isUploading = true;
      });
      final cloudinary = ref.read(cloudinaryServiceProvider);
      final url = await cloudinary.uploadImage(_photoFile!, folder: 'heartech/profiles');
      if (mounted) {
        setState(() {
          _photoUrl = url;
          _isUploading = false;
        });
      }
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
        role: 'teacher',
        name: _nameController.text.trim(),
        gender: _gender,
        profilePhotoUrl: _photoUrl,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        schoolName: _schoolController.text.trim(),
        gradeLevelsTaught: _selectedGrades.toList(),
        yearsExperience: int.tryParse(_yearsController.text),
        city: _cityController.text.trim(),
      );

      await firestoreService.setUser(user);

      // Register OneSignal
      await authService.registerOneSignal(uid, 'teacher');

      if (mounted) context.go(Routes.teacherDashboard);
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
    if (error.contains('weak-password')) return 'Password is too weak (min 6 chars).';
    if (error.contains('invalid-email')) return 'Invalid email address.';
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
            : IconButton(icon: const Icon(Icons.close, color: HearTechColors.textPrimary), onPressed: () => context.go(Routes.teacherLogin)),
        title: Text('Teacher Registration', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: StepIndicator(totalSteps: 5, currentStep: _currentStep),
            ),
            // Animated progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (_currentStep + 1) / 5),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor: HearTechColors.paleTeal,
                    valueColor: const AlwaysStoppedAnimation<Color>(HearTechColors.deepTeal),
                  ),
                ),
              ),
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
        HearTechInputField(controller: _confirmPasswordController, label: 'Confirm Password',
          prefixIcon: Icons.lock_outline, obscureText: true,
          validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null),
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
        const SizedBox(height: 20),
        // Gender chips
        Text('Gender', style: HearTechTextStyles.subtitle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: ['Male', 'Female', 'Prefer not to say'].map((g) {
            final selected = _gender == g;
            return ChoiceChip(
              label: Text(g),
              selected: selected,
              selectedColor: HearTechColors.deepTeal,
              backgroundColor: HearTechColors.paleTeal,
              labelStyle: TextStyle(
                color: selected ? HearTechColors.white : HearTechColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              onSelected: (val) => setState(() => _gender = val ? g : null),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        HearTechButton(label: 'Continue', onPressed: _nextStep),
      ],
    ));
  }

  Widget _buildProfessionalStep() {
    return Form(key: _formKeys[2], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('School & Teaching', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 3 of 5', style: HearTechTextStyles.caption()),
        const SizedBox(height: 32),
        HearTechInputField(controller: _schoolController, label: 'School Name', prefixIcon: Icons.school_outlined,
          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
        const SizedBox(height: 20),
        Text('Grade Levels Taught', style: HearTechTextStyles.subtitle()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _allGrades.map((grade) {
            final selected = _selectedGrades.contains(grade);
            return FilterChip(
              label: Text(grade),
              selected: selected,
              selectedColor: HearTechColors.deepTeal,
              backgroundColor: HearTechColors.paleTeal,
              checkmarkColor: HearTechColors.white,
              labelStyle: TextStyle(
                color: selected ? HearTechColors.white : HearTechColors.textPrimary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) { _selectedGrades.add(grade); }
                  else { _selectedGrades.remove(grade); }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        HearTechInputField(controller: _cityController, label: 'City', prefixIcon: Icons.location_city_outlined),
        const SizedBox(height: 16),
        HearTechInputField(controller: _yearsController, label: 'Years of Experience', prefixIcon: Icons.timeline_outlined,
          keyboardType: TextInputType.number),
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
            onTap: _isUploading ? null : _pickPhoto,
            child: Stack(children: [
              CircleAvatar(radius: 60, backgroundColor: HearTechColors.paleTeal,
                backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                child: _photoFile == null ? const Icon(Icons.camera_alt_outlined, size: 32, color: HearTechColors.deepTeal) : null),
              if (_isUploading)
                const Positioned.fill(child: CircularProgressIndicator(
                  strokeWidth: 3, valueColor: AlwaysStoppedAnimation(HearTechColors.deepTeal),
                )),
            ]),
          ),
        ),
        if (_photoUrl != null) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle, color: HearTechColors.green, size: 16),
            const SizedBox(width: 4),
            Text('Photo uploaded', style: HearTechTextStyles.caption(color: HearTechColors.green)),
          ]),
        ],
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
        Text('Review & Submit', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 5 of 5 — Confirm your details', style: HearTechTextStyles.caption()),
        const SizedBox(height: 24),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_photoFile != null) ...[
              Center(child: CircleAvatar(radius: 40, backgroundImage: FileImage(_photoFile!))),
              const SizedBox(height: 16),
            ],
            _r('Name', _nameController.text),
            _r('Gender', _gender ?? '-'),
            _r('School', _schoolController.text.isNotEmpty ? _schoolController.text : '-'),
            _r('Grades', _selectedGrades.isNotEmpty ? _selectedGrades.join(', ') : '-'),
            _r('City', _cityController.text.isNotEmpty ? _cityController.text : '-'),
            _r('Experience', _yearsController.text.isNotEmpty ? '${_yearsController.text} years' : '-'),
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
