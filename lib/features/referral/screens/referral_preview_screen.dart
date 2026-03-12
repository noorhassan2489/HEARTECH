import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ReferralPreviewScreen extends StatefulWidget {
  final String childId;
  const ReferralPreviewScreen({super.key, required this.childId});

  @override
  State<ReferralPreviewScreen> createState() => _ReferralPreviewScreenState();
}

class _ReferralPreviewScreenState extends State<ReferralPreviewScreen> {
  bool _isGenerating = true;
  String? _referralText;

  @override
  void initState() {
    super.initState();
    _generateReferral();
  }

  Future<void> _generateReferral() async {
    // In full implementation:
    // _referralText = await FastApiService.generateReferral(...)
    
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _referralText = """Date: March 15, 2026
        
To: Pediatric Audiology Department

Re: Medical Referral for Hearing Evaluation
Patient: Liam
Age: 2-3 years

Dear Colleague,

I am writing to formally refer Liam for a comprehensive pediatric audiological evaluation. During a recent screening using the HearTech application, Liam was identified as having a "High" risk for potential hearing concerns. 

The screening revealed a missed response across multiple fundamental speech frequencies in the Ling Six Sound Test, and the parent reported a lack of response to high-frequency sounds at home. Furthermore, a clinical flag for recent chronic ear infections was noted.

Given these indicators, an urgent evaluation is highly recommended to rule out or diagnose any conductive or sensorineural hearing loss and effectively plan early intervention strategies.

Thank you for your prompt attention to this referral.

Sincerely,
System Generated Referral
HearTech Platform""";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Referral Letter', style: AppTheme.heading2),
        centerTitle: true,
        actions: [
          if (!_isGenerating)
            IconButton(
              icon: const Icon(Icons.share, color: AppTheme.primaryTeal),
              onPressed: () {
                // Share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Sharing mock...'))
                );
              },
            )
        ],
      ),
      body: _isGenerating
          ? _buildLoadingState()
          : _buildPreviewState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryTeal),
          const SizedBox(height: 24),
          Text(
            'Gemini AI is drafting\nthe referral letter...',
            textAlign: TextAlign.center,
            style: AppTheme.heading2.copyWith(color: AppTheme.textSecondary),
          )
        ],
      ),
    );
  }

  Widget _buildPreviewState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          color: AppTheme.primaryTeal.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppTheme.primaryTeal),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Drafted by Gemini AI',
                  style: AppTheme.caption.copyWith(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: Text(
                _referralText!,
                style: const TextStyle(
                  fontFamily: 'Courier', // Typewriter feel for a letter
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
            ]
          ),
          child: Row(
            children: [
               Expanded(
                 child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.primaryTeal),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('EDIT', style: AppTheme.buttonText.copyWith(color: AppTheme.primaryTeal)),
                  ),
               ),
               const SizedBox(width: 16),
               Expanded(
                 child: ElevatedButton(
                    onPressed: () {
                      // Generate PDF mock
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Downloading PDF...'))
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('DOWNLOAD PDF', style: AppTheme.buttonText),
                  ),
               ),
            ],
          ),
        )
      ],
    );
  }
}
