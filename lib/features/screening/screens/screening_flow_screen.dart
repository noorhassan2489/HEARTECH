import 'package:flutter/material.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/questionnaire_data.dart';
import '../widgets/question_card.dart';
import '../widgets/screening_result_card.dart';

// Internal state for the wizard is managed completely within the StatefulWidget.



class ScreeningFlowScreen extends StatefulWidget {
  final String role; // 'Healthcare Worker', 'Parent', 'Teacher'
  final Map<String, dynamic>? initialInfo; // { 'childName': ..., 'dob': ..., 'gender': ... }

  const ScreeningFlowScreen({
    super.key,
    this.role = 'Healthcare Worker',
    this.initialInfo,
  });

  @override
  State<ScreeningFlowScreen> createState() => _ScreeningFlowScreenState();
}

class _ScreeningFlowScreenState extends State<ScreeningFlowScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  List<Question> _questions = [];
  String _calculatedBracket = "3+ years";
  bool _isLoading = false;

  Map<String, dynamic> _screeningState = {
    'childName': '',
    'dob': null,
    'gender': '',
    'responses': <String, int>{},
    'riskScore': 0.0,
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialInfo != null) {
      _screeningState['childName'] = widget.initialInfo!['childName'] ?? '';
      _screeningState['dob'] = widget.initialInfo!['dob'];
      _screeningState['gender'] = widget.initialInfo!['gender'] ?? '';
      
      // If we have all required info, skip step 0
      if (_screeningState['childName'].isNotEmpty && _screeningState['dob'] != null && _screeningState['gender'].isNotEmpty) {
        // We defer this so the UI can build first before changing steps
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _calculateBracketAndLoadQuestions();
          _nextStep(); // skip info step automatically
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Transitioning from info to questionnaire
      if (_screeningState['childName'].isEmpty || _screeningState['dob'] == null || _screeningState['gender'].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all child info fields.')),
        );
        return;
      }
      
      _calculateBracketAndLoadQuestions();
    } else if (_currentStep > 0 && _currentStep <= _questions.length) {
      // Checking if question was answered
      final qIndex = _currentStep - 1;
      final qId = _questions[qIndex].id;
      
      if (!_screeningState['responses'].containsKey(qId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an option.')),
        );
        return;
      }
    }

    if (_currentStep == _questions.length) {
      // Finished questions, calculate risk
      _calculateRiskScore();
    } else {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _calculateBracketAndLoadQuestions() {
    final DateTime dob = _screeningState['dob'];
    final months = DateTime.now().difference(dob).inDays / 30.44;

    if (months <= 6) {
      _calculatedBracket = "0-6 months";
    } else if (months <= 12) {
      _calculatedBracket = "6-12 months";
    } else if (months <= 24) {
      _calculatedBracket = "1-2 years";
    } else if (months <= 36) {
      _calculatedBracket = "2-3 years";
    } else {
      _calculatedBracket = "3+ years";
    }

    // Map role string to questionnaire key
    String roleKey = 'hcw';
    if (widget.role.toLowerCase().contains('parent')) roleKey = 'parent';
    if (widget.role.toLowerCase().contains('teacher')) roleKey = 'teacher';
    
    _questions = QuestionnaireData.getQuestions(roleKey, _calculatedBracket);
    
    setState(() => _currentStep++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _calculateRiskScore() async {
    setState(() => _isLoading = true);
    
    // In Phase 5 this will call FastAPI. For now, local heuristic.
    await Future.delayed(const Duration(seconds: 1)); // simulate network
    
    final Map<String, int> responses = _screeningState['responses'];
    
    int totalScore = 0;
    int maxPossScore = _questions.length * 2;
    
    for (var q in _questions) {
      totalScore += responses[q.id] ?? 0;
    }

    double risk = totalScore / maxPossScore;
    
    // Clinical flag bump
    for (var q in _questions) {
      if (q.isClinical && responses[q.id] == 2) {
        risk = risk < 0.8 ? risk + 0.3 : 1.0; // Auto-high risk
      }
    }
    
    if (risk > 1.0) risk = 1.0;

    _screeningState['riskScore'] = risk;

    setState(() {
      _isLoading = false;
      _currentStep++;
    });
    
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = 1 + (_questions.isNotEmpty ? _questions.length : 1) + 1; // Info + Qs + Result

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _currentStep == 0 
            ? 'Child Info' 
            : _currentStep <= _questions.length 
              ? 'Question $_currentStep of ${_questions.length}'
              : 'Screening Result',
          style: AppTheme.heading2,
        ),
        actions: [
          if (_currentStep <= _questions.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Text(
                  'Step ${_currentStep + 1} of $totalSteps',
                  style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal),
                ),
              ),
            ),
        ],
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              LinearProgressIndicator(
                value: (_currentStep + 1) / totalSteps,
                backgroundColor: AppTheme.dividerColor,
                color: AppTheme.primaryTeal,
                minHeight: 4,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Disable swipe
                  children: [
                    _buildChildInfoStep(),
                    ..._questions.map((q) => _buildQuestionStep(q)),
                    if (_questions.isNotEmpty) _buildResultStep(),
                  ],
                ),
              ),
              if (_currentStep <= _questions.length)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentStep == _questions.length ? 'SUBMIT ASSESSMENT' : 'NEXT',
                        style: AppTheme.buttonText.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.8),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryTeal),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChildInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Basic Information", style: AppTheme.heading1),
          const SizedBox(height: 8),
          Text("Let's start by getting some details about the child.", style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 32),
          
          // Name Field
          Text("Child's First Name", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: 'e.g. Liam',
              filled: true,
              fillColor: AppTheme.primaryPale,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() {
                _screeningState['childName'] = val;
              });
            },
          ),
          const SizedBox(height: 24),
          
          // DOB Field
          Text("Date of Birth", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _screeningState['dob'] = date;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryPale,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _screeningState['dob'] == null 
                      ? 'Select Date' 
                      : '${_screeningState['dob'].year}-${_screeningState['dob'].month.toString().padLeft(2, '0')}-${_screeningState['dob'].day.toString().padLeft(2, '0')}',
                    style: AppTheme.bodyText.copyWith(
                      color: _screeningState['dob'] == null ? AppTheme.textSecondary : AppTheme.textPrimary,
                    ),
                  ),
                  const Icon(Icons.calendar_today, color: AppTheme.primaryTeal, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Gender
          Text("Gender", style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildGenderChip('Male'),
              const SizedBox(width: 12),
              _buildGenderChip('Female'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    final isSelected = _screeningState['gender'] == label;
    return ChoiceChip(
      label: Text(label, style: AppTheme.bodyText.copyWith(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      )),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _screeningState['gender'] = label;
          });
        }
      },
      selectedColor: AppTheme.primaryTeal,
      backgroundColor: AppTheme.primaryPale,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      showCheckmark: false,
    );
  }

  Widget _buildQuestionStep(Question q) {
    final responses = _screeningState['responses'] as Map<String, int>;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "Age Bracket: $_calculatedBracket",
              style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          QuestionCard(
            question: q,
            selectedScore: responses[q.id],
            onOptionSelected: (score) {
              setState(() {
                _screeningState['responses'][q.id] = score;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          ScreeningResultCard(
            riskScore: _screeningState['riskScore'] as double,
            isHCW: widget.role == 'Healthcare Worker', 
            onActionPressed: () {
              if (widget.role == 'Healthcare Worker') {
                // Navigate to child profile creation with screening data
                Navigator.pushReplacementNamed(
                  context, AppRouter.childCreate,
                  arguments: _screeningState,
                );
              } else {
                // Parent/Teacher go back to their dashboard
                String route = AppRouter.parentDashboard;
                if (widget.role.toLowerCase().contains('teacher')) {
                  route = AppRouter.teacherDashboard;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  route,
                  (r) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

