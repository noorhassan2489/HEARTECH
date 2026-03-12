import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LingSixScreen extends StatefulWidget {
  final String childId;
  const LingSixScreen({super.key, required this.childId});

  @override
  State<LingSixScreen> createState() => _LingSixScreenState();
}

class _LingSixScreenState extends State<LingSixScreen> {
  final List<Map<String, String>> _sounds = [
    {'name': '/m/', 'sound': 'mmmmm', 'color': '0xFF9B51E0'},
    {'name': '/u/', 'sound': 'ooooo', 'color': '0xFF2D9CDB'},
    {'name': '/a/', 'sound': 'ahhhh', 'color': '0xFF27AE60'},
    {'name': '/i/', 'sound': 'eeeee', 'color': '0xFFF2C94C'},
    {'name': '/sh/', 'sound': 'shhhh', 'color': '0xFFF2994A'},
    {'name': '/s/', 'sound': 'sssss', 'color': '0xFFEB5757'},
  ];
  
  final Map<String, bool> _responses = {};
  bool _isFinished = false;

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildResults();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Ling Six Test', style: AppTheme.heading2),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text("Fundmental Frequencies", style: AppTheme.heading1),
            const SizedBox(height: 8),
            Text(
              "Play each sound and mark if the child reacts (turns head, smiles, widens eyes). Stand 1 meter behind them.",
              style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            ..._sounds.map((sound) => _buildSoundRow(sound)),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _responses.length == 6 
                  ? () => setState(() => _isFinished = true) 
                  : null, // Disabled until all 6 are checked/unchecked
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: AppTheme.dividerColor,
                ),
                child: Text('ANALYZE RESULTS', style: AppTheme.buttonText.copyWith(
                  color: _responses.length == 6 ? Colors.white : AppTheme.textSecondary
                )),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSoundRow(Map<String, String> sound) {
    final hasResponse = _responses.containsKey(sound['name']);
    final isHeard = hasResponse ? _responses[sound['name']]! : false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          // Play button
          IconButton(
            onPressed: () {
              // TODO: Play audio asset
            },
            icon: const Icon(Icons.play_circle_fill, size: 40, color: AppTheme.primaryTeal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sound['name']!, style: AppTheme.heading2),
                Text('"${sound['sound']!}"', style: AppTheme.caption.copyWith(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          // Yes / No toggles
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _responses[sound['name']!] = false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasResponse && !isHeard ? AppTheme.accentCoral : Colors.transparent,
                    border: Border.all(color: hasResponse && !isHeard ? AppTheme.accentCoral : AppTheme.dividerColor),
                  ),
                  child: Icon(Icons.close, size: 20, color: hasResponse && !isHeard ? Colors.white : AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _responses[sound['name']!] = true),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasResponse && isHeard ? AppTheme.accentGreen : Colors.transparent,
                    border: Border.all(color: hasResponse && isHeard ? AppTheme.accentGreen : AppTheme.dividerColor),
                  ),
                  child: Icon(Icons.check, size: 20, color: hasResponse && isHeard ? Colors.white : AppTheme.textSecondary),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
  
  Widget _buildResults() {
    int heardCount = _responses.values.where((v) => v).length;
    double percentage = (heardCount / 6) * 100;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text('Test Results', style: AppTheme.heading2)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                percentage == 100 ? Icons.celebration : Icons.warning_amber_rounded,
                size: 80,
                color: percentage == 100 ? AppTheme.accentGreen : AppTheme.accentCoral,
              ),
              const SizedBox(height: 24),
              Text(
                '${percentage.toInt()}% Response',
                style: AppTheme.display.copyWith(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                percentage == 100 
                  ? 'Excellent! The child responded to all fundamental speech frequencies.'
                  : 'The child missed ${6 - heardCount} sounds. We recommend consulting with an Audiologist.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyText,
              ),
              const SizedBox(height: 48),
               SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryTeal),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('DONE', style: AppTheme.buttonText.copyWith(color: AppTheme.primaryTeal)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
