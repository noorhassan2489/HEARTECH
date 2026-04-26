import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/shared/widgets/heartech_button.dart';
import 'package:heartech/shared/widgets/avatar_circle.dart';

/// Parent Handover Code Entry — 6-box OTP input, validated via FastAPI,
/// animated success with child name + avatar.
class ClaimProfileScreen extends ConsumerStatefulWidget {
  const ClaimProfileScreen({super.key});
  @override
  ConsumerState<ClaimProfileScreen> createState() => _ClaimProfileScreenState();
}

class _ClaimProfileScreenState extends ConsumerState<ClaimProfileScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _showSuccess = false;
  String? _errorMessage;

  // Success data
  String _childName = '';
  String _childId = '';

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    // Paste support: if user pastes 6 characters into first box
    if (value.length > 1 && index == 0) {
      final chars = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      for (int i = 0; i < 6 && i < chars.length; i++) {
        _controllers[i].text = chars[i];
      }
      if (chars.length >= 6) {
        _focusNodes[5].requestFocus();
      }
      setState(() => _errorMessage = null);
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  void _onBackspace(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fastApi = ref.read(fastApiServiceProvider);
      final result = await fastApi.claimProfile(code: code);

      // Check for error responses
      if (result.containsKey('error')) {
        final error = result['error'] as String;
        String msg;
        switch (error) {
          case 'invalid':
            msg =
                "This code doesn't match any profile. Please check with your HCW.";
            break;
          case 'expired':
            msg =
                'This code has expired (valid 24 hours). Ask your HCW to regenerate.';
            break;
          case 'already_used':
            msg =
                "This code has already been used. Contact your HCW if this wasn't you.";
            break;
          case 'rate_limited':
            msg =
                'Too many attempts. Please wait a few minutes before trying again.';
            break;
          case 'network_error':
            msg =
                'Could not connect to the server. Check your internet and try again.';
            break;
          default:
            msg = 'Something went wrong. Please try again.';
        }
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
        return;
      }

      // Success
      _childName = result['childName'] as String? ?? '';
      _childId = result['childId'] as String? ?? '';

      setState(() {
        _showSuccess = true;
        _isLoading = false;
      });

      // Auto navigate after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ref.invalidate(parentChildrenProvider);
        context.go(
          Routes.parentChildProfile.replaceFirst(':childId', _childId),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) return _buildSuccess();

    return Scaffold(
      backgroundColor: HearTechColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: HearTechColors.textPrimary),
          onPressed: () => context.go(Routes.parentDashboard),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),

            // HearTech ear icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: HearTechColors.deepTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hearing,
                size: 48,
                color: HearTechColors.deepTeal,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),

            Text('Link Child Profile', style: HearTechTextStyles.screenTitle()),
            const SizedBox(height: 8),
            Text(
              'Enter the 6-character code your healthcare worker gave you.',
              style: HearTechTextStyles.body(
                color: HearTechColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 6-box OTP input with auto-advance
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) {
                return Container(
                      width: 44,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (event) => _onBackspace(i, event),
                        child: TextFormField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          style: HearTechTextStyles.screenTitle().copyWith(
                            fontSize: 22,
                          ),
                          maxLength: i == 0 ? 6 : 1, // Allow paste on first box
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z0-9]'),
                            ),
                            _UpperCaseFormatter(),
                          ],
                          onChanged: (v) => _onChanged(i, v),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            filled: true,
                            fillColor: _errorMessage != null
                                ? HearTechColors.coralRed.withValues(
                                    alpha: 0.05,
                                  )
                                : HearTechColors.paleTeal,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: HearTechColors.deepTeal.withValues(
                                  alpha: 0.2,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: HearTechColors.deepTeal,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _errorMessage != null
                                    ? HearTechColors.coralRed
                                    : HearTechColors.deepTeal.withValues(
                                        alpha: 0.2,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .animate(delay: (i * 80).ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 200.ms,
                    );
              }),
            ),
            const SizedBox(height: 16),

            // Error card
            if (_errorMessage != null)
              Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HearTechColors.coralRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HearTechColors.coralRed.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 20,
                          color: HearTechColors.coralRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: HearTechTextStyles.caption(
                              color: HearTechColors.coralRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 200.ms)
                  .shake(hz: 3, offset: const Offset(4, 0), duration: 300.ms),

            const SizedBox(height: 32),
            HearTechButton(
              label: 'Link Profile',
              onPressed: _code.length == 6 ? _claimProfile : null,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HearTechColors.paleTeal,
                borderRadius: HearTechDecorations.cardBorderRadius,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: HearTechColors.deepTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Don't have a code? Ask your healthcare worker to generate one from the child's profile.",
                      style: HearTechTextStyles.caption(
                        color: HearTechColors.deepTeal,
                      ),
                    ),
                  ),
                ],
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: HearTechColors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 72,
                  color: HearTechColors.green,
                ),
              ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
              const SizedBox(height: 24),
              Text(
                '$_childName has been added to your account!',
                style: HearTechTextStyles.subtitle(color: HearTechColors.green),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
              const SizedBox(height: 16),
              AvatarCircle(name: _childName, radius: 32)
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 300.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
