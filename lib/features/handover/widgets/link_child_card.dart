import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class LinkChildCard extends StatefulWidget {
  final Future<void> Function(String code) onSubmitCode;

  const LinkChildCard({super.key, required this.onSubmitCode});

  @override
  State<LinkChildCard> createState() => _LinkChildCardState();
}

class _LinkChildCardState extends State<LinkChildCard> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (value.length > 1) {
        // Handle paste
        final chars = value.toUpperCase().split('');
        for (int i = 0; i < 6 && (index + i) < 6 && i < chars.length; i++) {
          _controllers[index + i].text = chars[i];
          if ((index + i + 1) < 6) {
            _focusNodes[index + i + 1].requestFocus();
          } else {
            _focusNodes[5].unfocus();
          }
        }
      } else {
        // Handle single char
        _controllers[index].text = value.toUpperCase();
        if (index < 5) {
          _focusNodes[index + 1].requestFocus();
        } else {
          _focusNodes[5].unfocus();
        }
      }
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event.logicalKey == LogicalKeyboardKey.backspace && 
        _controllers[index].text.isEmpty && 
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleSubmit() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = "Please enter all 6 characters");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmitCode(code);
      // On success, clear the form
      for (var c in _controllers) { c.clear(); }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPale,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: AppTheme.primaryTeal),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Link a Child Profile", style: AppTheme.heading2),
                    const SizedBox(height: 4),
                    Text(
                      "Enter the 6-character code given by your Healthcare Worker.",
                      style: AppTheme.bodyText.copyWith(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) => _buildDigitBox(index)),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: AppTheme.caption.copyWith(color: AppTheme.accentCoral),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: AppTheme.primaryButton,
              onPressed: _isLoading ? null : _handleSubmit,
              child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Link Profile"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return Container(
      width: 48,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focusNodes[index].hasFocus ? AppTheme.primaryTeal : AppTheme.dividerColor,
          width: 2,
        ),
      ),
      child: KeyboardListener(
        focusNode: FocusNode(), // Dummy focus node for listener
        onKeyEvent: (event) => _onKeyEvent(event, index),
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          style: AppTheme.heading1.copyWith(color: AppTheme.primaryTeal),
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: (val) => _onChanged(val, index),
        ),
      ),
    );
  }
}
