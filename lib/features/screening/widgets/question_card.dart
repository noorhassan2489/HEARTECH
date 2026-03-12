import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/questionnaire_data.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final int? selectedScore;
  final Function(int) onOptionSelected;

  const QuestionCard({
    super.key,
    required this.question,
    this.selectedScore,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.dividerColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (question.isClinical) ...[
              Row(
                children: [
                  const Icon(Icons.medical_services, size: 16, color: AppTheme.accentCoral),
                  const SizedBox(width: 8),
                  Text(
                    'CLINICAL FLAG',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.accentCoral,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              question.text,
              style: AppTheme.heading2,
            ),
            const SizedBox(height: 24),
            ...question.options.map((option) {
              final isSelected = selectedScore == option.score;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: () => onOptionSelected(option.score),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryLight.withValues(alpha: 0.1) : AppTheme.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryTeal : AppTheme.dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? AppTheme.primaryTeal : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option.text,
                            style: AppTheme.bodyText.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppTheme.primaryTeal : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
