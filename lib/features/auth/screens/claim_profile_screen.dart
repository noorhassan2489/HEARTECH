import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';

/// Parent Claim Profile — 6-box OTP-style code input, animated success.
class ClaimProfileScreen extends ConsumerStatefulWidget {
  const ClaimProfileScreen({super.key});
  @override
  ConsumerState<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends ConsumerState<ClaimProfileScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;
  int _attempts = 0;

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  void _onBackspace(int index, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _claimProfile() async {
    final code = _code.toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 characters.');
      return;
    }

    if (_attempts >= 5) {
      setState(() => _errorMessage = 'Too many attempts. Please try again later.');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      await fastApi.claimProfile(code: code);
      _attempts = 0;

      // Show animated success
      setState(() { _showSuccess = true; _isLoading = false; });

      // Auto navigate after 2s
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ref.invalidate(parentChildrenProvider);
        context.go(Routes.parentDashboard);
      }
    } catch (e) {
      _attempts++;
      String msg;
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        msg = 'Invalid code. No matching profile found.';
      } else if (e.toString().contains('expired')) {
        msg = 'This code has expired. Ask your HCW for a new one.';
      } else if (e.toString().contains('claimed') || e.toString().contains('already')) {
        msg = 'This code has already been used.';
      } else {
        msg = 'Something went wrong. Please try again.';
      }
      setState(() { _errorMessage = msg; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) return _buildSuccess();

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
        title: Text('Claim Profile', style: HearTechTextStyles.sectionHeader()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.qr_code, size: 48, color: HearTechColors.deepTeal),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),

            Text('Enter Handover Code', style: HearTechTextStyles.screenTitle()),
            const SizedBox(height: 8),
            Text(
              "Your healthcare worker will provide this 6-character code after completing your child's hearing screening.",
              style: HearTechTextStyles.body(color: HearTechColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 6-box OTP input with auto-advance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return Container(
                  width: 48, height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) => _onBackspace(i, event),
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      textCapitalization: TextCapitalization.characters,
                      style: HearTechTextStyles.screenTitle().copyWith(fontSize: 22),
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                        _UpperCaseFormatter(),
                      ],
                      onChanged: (v) => _onChanged(i, v),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        filled: true,
                        fillColor: _errorMessage != null
                            ? HearTechColors.coralRed.withValues(alpha: 0.05)
                            : HearTechColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _errorMessage != null
                                ? HearTechColors.coralRed
                                : HearTechColors.deepTeal.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: HearTechColors.deepTeal, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _errorMessage != null
                                ? HearTechColors.coralRed
                                : HearTechColors.deepTeal.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: (i * 60).ms).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  duration: 200.ms,
                );
              }),
            ),
            const SizedBox(height: 12),

            // Error card
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HearTechColors.coralRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HearTechColors.coralRed.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 20, color: HearTechColors.coralRed),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMessage!, style: HearTechTextStyles.caption(color: HearTechColors.coralRed))),
                ]),
              ).animate().fadeIn(duration: 200.ms).shake(hz: 3, offset: const Offset(4, 0), duration: 300.ms),

            if (_attempts > 0 && _attempts < 5)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Attempt $_attempts/5', style: HearTechTextStyles.caption(color: HearTechColors.textSecondary)),
              ),

            const SizedBox(height: 32),
            HearTechButton(label: 'Claim Profile', onPressed: _claimProfile, isLoading: _isLoading),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: HearTechColors.deepTeal, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  "Don't have a code? Ask your healthcare worker to generate one from the child's profile.",
                  style: HearTechTextStyles.caption(color: HearTechColors.deepTeal),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Scaffold(
      backgroundColor: HearTechColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: HearTechColors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, size: 72, color: HearTechColors.green),
            ).animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text('Profile Linked!', style: HearTechTextStyles.screenTitle(color: HearTechColors.green))
                .animate(delay: 200.ms).fadeIn(duration: 300.ms),
            const SizedBox(height: 8),
            Text("Your child's profile has been linked to your account.",
                style: HearTechTextStyles.body(color: HearTechColors.textSecondary), textAlign: TextAlign.center)
                .animate(delay: 400.ms).fadeIn(duration: 300.ms),
          ],
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}
