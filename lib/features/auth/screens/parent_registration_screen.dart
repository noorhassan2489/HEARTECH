import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';
import '../widgets/step_indicator.dart';

class ParentRegistrationScreen extends StatefulWidget {
  const ParentRegistrationScreen({super.key});

  @override
  State<ParentRegistrationScreen> createState() => _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends State<ParentRegistrationScreen> {
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
  DateTime? _selectedDob;
  final _phoneController = TextEditingController();

  // Step 3: Location
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

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
      // 1. Create Auth User
      final userCred = await _authService.signUpWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      final uid = userCred.user!.uid;

      // 2. Create Firestore Profile
      await _firestoreService.setUserProfile(uid, {
        'uid': uid,
        'email': _emailController.text.trim().toLowerCase(),
        'role': AppConstants.roleParent,
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'dob': _selectedDob?.toIso8601String(),
        'phone': _phoneController.text.trim(),
        'location': {
          'city': _cityController.text.trim(),
          'country': _countryController.text.trim(),
        },
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(
          context, AppRouter.authCheck,
          arguments: {'uid': uid},
        );
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
          decoration: AppTheme.inputDecoration("Email Address", Icons.email_outlined),
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
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime(1990),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppTheme.primaryTeal,
                      onPrimary: Colors.white,
                      onSurface: AppTheme.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) setState(() => _selectedDob = date);
          },
          child: InputDecorator(
            decoration: AppTheme.inputDecoration("Date of Birth", Icons.calendar_today),
            child: Text(
              _selectedDob == null ? "Select Date" : "${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}",
              style: TextStyle(color: _selectedDob == null ? AppTheme.textSecondary : AppTheme.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: AppTheme.inputDecoration("Phone Number", Icons.phone_outlined),
        ),
      ],
    );
  }

  // ─── Step 3 Builder ──────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text("Location", style: AppTheme.heading2),
        const SizedBox(height: 8),
        Text("Used to suggest nearby hearing specialists.", style: AppTheme.subtitle),
        const SizedBox(height: 24),
        TextField(
          controller: _cityController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("City", Icons.location_city),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _countryController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("Country", Icons.public),
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
          "Review your details and tap Create Profile to begin tracking your child's hearing development.",
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
              Text("Email: ${_emailController.text}", style: AppTheme.bodyText),
              const SizedBox(height: 8),
              Text("City: ${_cityController.text}", style: AppTheme.bodyText),
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
