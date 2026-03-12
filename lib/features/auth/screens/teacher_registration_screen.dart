import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';
import '../widgets/step_indicator.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  const TeacherRegistrationScreen({super.key});

  @override
  State<TeacherRegistrationScreen> createState() => _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _authService = FirebaseAuthService();
  final _firestoreService = FirestoreService();
  final _pageController = PageController();
  
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Credentials
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Step 2: Personal
  final _nameController = TextEditingController();
  String? _selectedGender;

  // Step 3: School
  final _schoolController = TextEditingController();
  final _gradeController = TextEditingController();
  final _cityController = TextEditingController();

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      setState(() => _currentStep++);
    } else {
      _submitRegistration();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      final userCred = await _authService.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      final uid = userCred.user!.uid;

      await _firestoreService.setUserProfile(uid, {
        'uid': uid,
        'email': _emailController.text.trim().toLowerCase(),
        'role': AppConstants.roleTeacher,
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'schoolName': _schoolController.text.trim(),
        'gradeLevel': _gradeController.text.trim(),
        'location': {'city': _cityController.text.trim()},
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.teacherDashboard);
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

  // ─── Step 1 Builder ──────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Account Details", style: AppTheme.heading2),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: AppTheme.inputDecoration("Professional Email", Icons.email_outlined),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: AppTheme.inputDecoration("Password", Icons.lock_outline),
        ),
      ],
    );
  }

  // ─── Step 2 Builder ──────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Personal Information", style: AppTheme.heading2),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("Full Name", Icons.person_outline),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedGender,
          decoration: AppTheme.inputDecoration("Gender", Icons.wc),
          items: ['Male', 'Female', 'Other', 'Prefer not to say']
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
      ],
    );
  }

  // ─── Step 3 Builder ──────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("School Details", style: AppTheme.heading2),
        const SizedBox(height: 24),
        TextField(
          controller: _schoolController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("School Name", Icons.school_outlined),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _gradeController,
          decoration: AppTheme.inputDecoration("Grade/Class Level (e.g. Pre-K, 1st Grade)", Icons.child_care),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cityController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("City", Icons.location_city),
        ),
      ],
    );
  }

  // ─── Step 4 Builder ──────────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 80, color: AppTheme.accentGreen),
        const SizedBox(height: 24),
        Text("All Set!", textAlign: TextAlign.center, style: AppTheme.heading1),
        const SizedBox(height: 16),
        Text(
          "Review your details and tap Create Profile to begin recording classroom observations.",
          textAlign: TextAlign.center,
          style: AppTheme.bodyText,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryPale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Name: ${_nameController.text}", style: AppTheme.bodyText),
              const SizedBox(height: 8),
              Text("School: ${_schoolController.text}", style: AppTheme.bodyText),
              const SizedBox(height: 8),
              Text("Grade: ${_gradeController.text}", style: AppTheme.bodyText),
            ],
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _previousStep,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: StepIndicator(currentStep: _currentStep, totalSteps: 4),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStep1()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStep2()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStep3()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStep4()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: _isLoading ? null : _nextStep,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : Text(_currentStep == 3 ? "Create Profile" : "Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
