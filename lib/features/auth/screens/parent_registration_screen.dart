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
import 'package:heartech/shared/utils/media_upload.dart';
import 'package:heartech/shared/utils/registration_flow.dart';
import 'package:heartech/shared/widgets/registration_auth_step.dart';

/// Parent Registration — 5 step flow.
class ParentRegistrationScreen extends ConsumerStatefulWidget {
  const ParentRegistrationScreen({super.key});

  @override
  ConsumerState<ParentRegistrationScreen> createState() => _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends ConsumerState<ParentRegistrationScreen> {
  static const _role = 'parent';

  int _currentStep = 0;
  bool _isLoading = false;
  bool _isUploading = false;
  RegistrationSessionState _session = const RegistrationSessionState();

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
  final List<String> _countries = [
    'Pakistan', 'India', 'Bangladesh', 'Afghanistan', 'Sri Lanka',
    'Nepal', 'United Arab Emirates', 'Saudi Arabia', 'United Kingdom',
    'United States', 'Canada', 'Australia', 'Other',
  ];

  // Step 4 — Photo
  File? _photoFile;
  String? _photoUrl;

  final _formKeys = List.generate(5, (_) => GlobalKey<FormState>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSession());
  }

  Future<void> _loadSession() async {
    final session = await RegistrationFlow.prepareSession(
      ref: ref,
      currentRole: _role,
      emailController: _emailController,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      if (session.canContinue && session.resumeStep > 0) {
        _currentStep = session.resumeStep;
      }
    });
  }

  Future<void> _persistProgress() async {
    if (_currentStep < 1) return;
    await RegistrationFlow.saveProgress(
      ref: ref,
      role: _role,
      step: _currentStep,
    );
  }

  Future<void> _useDifferentAccount() async {
    await RegistrationFlow.signOutAndRestart(
      ref: ref,
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      onCleared: () {
        if (mounted) {
          setState(() {
            _currentStep = 0;
            _session = const RegistrationSessionState();
          });
        }
      },
    );
  }

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
    if (_currentStep == 0) {
      if (_session.canContinue) {
        setState(() => _currentStep = _session.resumeStep > 0 ? _session.resumeStep : 1);
        await _persistProgress();
        return;
      }
      if (_session.mode == RegistrationAuthMode.wrongRolePending) return;
      if (_formKeys[0].currentState?.validate() != true) return;

      setState(() => _isLoading = true);
      try {
        final authService = ref.read(firebaseAuthServiceProvider);
        await authService.createAccountWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
        await RegistrationFlow.markPendingRole(ref: ref, role: _role, step: 1);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_getAuthError(e.toString())), backgroundColor: HearTechColors.coralRed),
          );
          setState(() => _isLoading = false);
        }
        return;
      }
      if (!mounted) return;
      final session = await RegistrationFlow.loadSession(ref: ref, currentRole: _role);
      setState(() {
        _isLoading = false;
        _currentStep = 1;
        _session = session;
      });
      return;
    }

    if (_currentStep < 4 && _formKeys[_currentStep].currentState?.validate() != true) return;

    if (!mounted) return;
    if (_currentStep < 4) {
      setState(() => _currentStep++);
      await _persistProgress();
    } else {
      await _submitProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (_currentStep >= 1) _persistProgress();
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(firebaseAuthServiceProvider);
      final result = await authService.signInWithGoogle();
      if (!mounted) return;
      if (result != null) {
        _emailController.text = result.user?.email ?? '';
        _nameController.text = result.user?.displayName ?? '';
        await RegistrationFlow.markPendingRole(ref: ref, role: _role, step: 1);
        final session = await RegistrationFlow.loadSession(ref: ref, currentRole: _role);
        if (mounted) {
          setState(() {
            _currentStep = 1;
            _session = session;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: HearTechColors.deepTeal,
            onSurface: HearTechColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (picked == null || !mounted) return;
    setState(() {
      _photoFile = File(picked.path);
      _photoUrl = null;
      _isUploading = true;
    });
    final cloudinary = ref.read(cloudinaryServiceProvider);
    final url = await MediaUpload.uploadProfilePhoto(
      context: context,
      cloudinary: cloudinary,
      file: File(picked.path),
    );
    if (mounted) {
      setState(() {
        _photoUrl = url;
        _isUploading = false;
      });
    }
  }

  bool get _hasPendingPhotoUpload => _photoFile != null && _photoUrl == null;

  Future<void> _submitProfile() async {
    if (_hasPendingPhotoUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo upload incomplete — go back and tap photo to retry.'),
          backgroundColor: HearTechColors.coralRed,
        ),
      );
      return;
    }
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

      await RegistrationFlow.clearPendingRegistration();

      // Register OneSignal
      await authService.registerOneSignal(uid, 'parent');

      if (mounted) context.go(Routes.parentDashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: HearTechColors.coralRed),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String _getAuthError(String error) {
    if (error.contains('email-already-in-use')) return 'Email already registered. Try logging in.';
    if (error.contains('weak-password')) return 'Password is too weak (min 6 chars).';
    if (error.contains('invalid-email')) return 'Invalid email address.';
    return 'Registration failed. Please try again.';
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
      case 2: return _buildLocationStep();
      case 3: return _buildPhotoStep();
      case 4: return _buildReviewStep();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildAuthStep() {
    return RegistrationAuthStep(
      formKey: _formKeys[0],
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      obscurePassword: _obscurePassword,
      onToggleObscurePassword: () => setState(() => _obscurePassword = !_obscurePassword),
      isLoading: _isLoading,
      mode: _session.mode,
      currentRoleLabel: RegistrationFlow.roleLabel(_role),
      pendingRoleLabel: _session.pendingRole != null
          ? RegistrationFlow.roleLabel(_session.pendingRole!)
          : null,
      onPrimaryPressed: _nextStep,
      onGooglePressed: _signUpWithGoogle,
      onUseDifferentAccount: _useDifferentAccount,
      onGoToPendingRegistration: _session.pendingRole != null
          ? () => context.go(RegistrationFlow.registerRouteForRole(_session.pendingRole!))
          : null,
      totalSteps: 5,
    );
  }

  Widget _buildPersonalStep() {
    return Form(key: _formKeys[1], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About You', style: HearTechTextStyles.screenTitle()),
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
        const SizedBox(height: 20),
        // Date of Birth
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
          initialValue: _country,
          decoration: const InputDecoration(labelText: 'Country', prefixIcon: Icon(Icons.public)),
          items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _country = v),
        ),
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
            child: Stack(
              children: [
                CircleAvatar(radius: 60, backgroundColor: HearTechColors.paleTeal,
                  backgroundImage: _photoFile != null ? FileImage(_photoFile!) : null,
                  child: _photoFile == null
                      ? const Icon(Icons.camera_alt_outlined, size: 32, color: HearTechColors.deepTeal)
                      : null),
                if (_isUploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(
                      strokeWidth: 3, valueColor: AlwaysStoppedAnimation(HearTechColors.deepTeal),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_photoUrl != null) ...[
          const SizedBox(height: 8),
          UploadStatusRow(
            hasLocalFile: _photoFile != null,
            uploadedUrl: _photoUrl,
            successLabel: 'Photo uploaded',
          ),
        ] else if (_photoFile != null) ...[
          const SizedBox(height: 8),
          UploadStatusRow(
            hasLocalFile: true,
            uploadedUrl: null,
            failureLabel: 'Upload failed — tap photo to retry',
          ),
        ],
        const SizedBox(height: 16),
        Center(child: TextButton(
          onPressed: _isUploading ? null : _pickPhoto,
          child: Text('Choose Photo', style: HearTechTextStyles.body(color: HearTechColors.deepTeal)),
        )),
        const SizedBox(height: 32),
        HearTechButton(label: 'Continue', onPressed: _nextStep),
        const SizedBox(height: 12),
        Center(child: TextButton(
          onPressed: () {
            _photoFile = null;
            _photoUrl = null;
            _nextStep();
          },
          child: Text('Skip for now', style: HearTechTextStyles.body(color: HearTechColors.textSecondary)),
        )),
      ],
    ));
  }

  Widget _buildReviewStep() {
    return Form(key: _formKeys[4], child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review & Create', style: HearTechTextStyles.screenTitle()),
        const SizedBox(height: 8),
        Text('Step 5 of 5 — Confirm your details', style: HearTechTextStyles.caption()),
        const SizedBox(height: 24),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: HearTechDecorations.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_hasPendingPhotoUpload) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: HearTechColors.coralRed.withValues(alpha: 0.1),
                  borderRadius: HearTechDecorations.cardBorderRadius,
                ),
                child: Text(
                  'Profile photo upload failed. Go back to Step 4 and retry before submitting.',
                  style: HearTechTextStyles.caption(color: HearTechColors.coralRed),
                ),
              ),
            ],
            if (_photoUrl != null) ...[
              Center(child: CircleAvatar(radius: 40, backgroundImage: NetworkImage(_photoUrl!))),
              const SizedBox(height: 16),
            ] else if (_photoFile != null) ...[
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: HearTechColors.paleTeal,
                  child: const Icon(Icons.warning_amber, color: HearTechColors.coralRed),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
