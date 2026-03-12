import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// MOCK FOR DEMONSTRATION PURPOSES ONLY - In full implementation, connect to FastAPI
class ShowAndTellScreen extends StatefulWidget {
  final String childId;
  const ShowAndTellScreen({super.key, required this.childId});

  @override
  State<ShowAndTellScreen> createState() => _ShowAndTellScreenState();
}

class _ShowAndTellScreenState extends State<ShowAndTellScreen> {
  bool _isRecording = false;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  
  // Audio record mock
  // late final AudioRecorder _audioRecorder;

  // final String _targetWord = "Dog"; // Picture of a dog

  @override
  void initState() {
    super.initState();
    // _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    // _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _result = null;
    });
    // In full implementation:
    // await _audioRecorder.start(const RecordConfig(), path: '...');
  }

  Future<void> _stopRecordingAndAnalyze() async {
    setState(() {
      _isRecording = false;
      _isAnalyzing = true;
    });
    
    // In full implementation:
    // final path = await _audioRecorder.stop();
    // final result = await FastApiService.analyzeSpeech(path, _targetWord);
    
    // MOCK DELAY & FASTAPI RESPONSE
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _result = {
          'transcription': 'it is a dog',
          'target_word': 'dog',
          'match_score': 100.0,
          'accuracy_level': 'Excellent'
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Show & Tell', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("What's in the picture?", style: AppTheme.heading1),
            const SizedBox(height: 8),
            Text("Tap the mic and ask the child to describe the image.", style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary), textAlign: TextAlign.center,),
            const SizedBox(height: 32),
            
            // Image Card
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: const Center(
                child: Icon(Icons.pets, size: 100, color: AppTheme.primaryTeal),
              ),
            ),
            
            const SizedBox(height: 48),
            
            if (_isAnalyzing)
              const Column(
                children: [
                   CircularProgressIndicator(color: AppTheme.primaryTeal),
                   SizedBox(height: 16),
                   Text("Analyzing speech with AI...", style: TextStyle(color: AppTheme.textSecondary)),
                ],
              )
            else if (_result != null)
              _buildResultCard()
            else
              _buildRecordButton(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecordButton() {
    return GestureDetector(
      onTapDown: (_) => _startRecording(),
      onTapUp: (_) => _stopRecordingAndAnalyze(),
      onTapCancel: () => _stopRecordingAndAnalyze(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isRecording ? 100 : 80,
        width: _isRecording ? 100 : 80,
        decoration: BoxDecoration(
          color: _isRecording ? AppTheme.accentCoral : AppTheme.primaryTeal,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (_isRecording ? AppTheme.accentCoral : AppTheme.primaryTeal).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: _isRecording ? 10 : 5,
            )
          ]
        ),
        child: Icon(
          _isRecording ? Icons.mic : Icons.mic_none, 
          color: Colors.white, 
          size: _isRecording ? 48 : 36
        ),
      ),
    );
  }
  
  Widget _buildResultCard() {
    Color accColor = AppTheme.primaryTeal;
    if (_result!['accuracy_level'] == 'Good') accColor = AppTheme.accentGreen;
    if (_result!['accuracy_level'] == 'Needs Practice') accColor = const Color(0xFFF2994A);
    if (_result!['accuracy_level'] == 'Unclear') accColor = AppTheme.accentCoral;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: accColor),
              const SizedBox(width: 8),
              Text(_result!['accuracy_level'], style: AppTheme.heading2.copyWith(color: accColor)),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Child said:', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
              Text('"${_result!['transcription']}"', style: AppTheme.bodyText.copyWith(fontStyle: FontStyle.italic)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Target word:', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
              Text('"${_result!['target_word']}"', style: AppTheme.bodyText),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () {
                setState(() { _result = null; });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryTeal,
                side: const BorderSide(color: AppTheme.primaryTeal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('TRY AGAIN'),
            ),
          )
        ],
      ),
    );
  }
}
