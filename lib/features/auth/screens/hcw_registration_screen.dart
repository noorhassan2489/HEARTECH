import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../core/constants/app_constants.dart';
import '../widgets/step_indicator.dart';

class HCWRegistrationScreen extends StatefulWidget {
  const HCWRegistrationScreen({super.key});

  @override
  State<HCWRegistrationScreen> createState() => _HCWRegistrationScreenState();
}

class _HCWRegistrationScreenState extends State<HCWRegistrationScreen> {
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
  String? _selectedTitle;

  // Step 3: Professional
  final _licenseController = TextEditingController();
  final _specializationController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _cityController = TextEditingController();

  // Step 4: Verification (License Document - Mocked for now)
  String? _uploadedLicenseUrl;

  void _nextStep() {
    if (_currentStep < 4) {
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

  Future<void> _mockUploadLicense() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _uploadedLicenseUrl = "https://res.cloudinary.com/demo/image/upload/sample.jpg";
      _isLoading = false;
    });
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
        'role': AppConstants.roleHcw,
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'title': _selectedTitle,
        'licenseNumber': _licenseController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'hospitalName': _hospitalController.text.trim(),
        'location': {'city': _cityController.text.trim()},
        'licenseDocUrl': _uploadedLicenseUrl,
        'isVerified': false, // Admin must verify
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.hcwDashboard);
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
        DropdownButtonFormField<String>(
          initialValue: _selectedTitle,
          decoration: AppTheme.inputDecoration("Title", Icons.badge_outlined),
          items: ['Dr.', 'Nurse', 'Audiologist', 'Specialist', 'Other']
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) => setState(() => _selectedTitle = v),
        ),
        const SizedBox(height: 16),
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
        Text("Professional Credentials", style: AppTheme.heading2),
        const SizedBox(height: 24),
        TextField(
          controller: _licenseController,
          decoration: AppTheme.inputDecoration("Medical License Number", Icons.tag),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _specializationController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("Specialization", Icons.workspace_premium),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _hospitalController,
          textCapitalization: TextCapitalization.words,
          decoration: AppTheme.inputDecoration("Hospital / Clinic Name", Icons.local_hospital),
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
        Text("License Verification", style: AppTheme.heading2),
        const SizedBox(height: 8),
        Text("Upload a clear photo of your medical license or ID badge.", style: AppTheme.subtitle),
        const SizedBox(height: 24),
        
        if (_uploadedLicenseUrl != null)
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.safeGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.safeGreen, width: 2),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 48),
                  SizedBox(height: 8),
                  Text("Document Uploaded Successfully", style: TextStyle(color: AppTheme.safeGreen, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        else
          InkWell(
            onTap: _mockUploadLicense,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryTeal, width: 2, style: BorderStyle.solid),
              ),
              child: Center(
                child: _isLoading 
                  ? const CircularProgressIndicator()
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file, color: AppTheme.primaryTeal, size: 48),
                        SizedBox(height: 8),
                        Text("Tap to Upload Document", style: TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold)),
                      ],
                    ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Step 5 Builder ──────────────────────────────
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.verified_user_outlined, size: 80, color: AppTheme.primaryTeal),
        const SizedBox(height: 24),
        Text("Review & Submit", textAlign: TextAlign.center, style: AppTheme.heading1),
        const SizedBox(height: 16),
        Text(
          "Your profile will be in 'Pending Verification' state until our admin team reviews your license.",
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
              Text("Name: $_selectedTitle ${_nameController.text}", style: AppTheme.bodyText),
              const SizedBox(height: 8),
              Text("License: ${_licenseController.text}", style: AppTheme.bodyText),
              const SizedBox(height: 8),
              Text("Hospital: ${_hospitalController.text}", style: AppTheme.bodyText),
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
              child: StepIndicator(currentStep: _currentStep, totalSteps: 5),
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
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildStep5()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                style: AppTheme.primaryButton,
                onPressed: (_currentStep == 3 && _uploadedLicenseUrl == null) || _isLoading ? null : _nextStep,
                child: _isLoading && _currentStep == 4
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : Text(_currentStep == 4 ? "Submit Registration" : "Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
