import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import 'dart:math' as math;

class RiskGauge extends StatelessWidget {
  final double riskScore; // 0.0 to 1.0 (1.0 is highest risk)
  
  const RiskGauge({
    super.key,
    required this.riskScore,
  });

  Color _getRiskColor() {
    if (riskScore < 0.3) return AppTheme.accentGreen;
    if (riskScore < 0.7) return Colors.amber.shade600;
    return AppTheme.accentCoral;
  }

  String _getRiskLabel() {
    if (riskScore < 0.3) return "LOW RISK";
    if (riskScore < 0.7) return "MEDIUM RISK";
    return "HIGH RISK";
  }

  @override
  Widget build(BuildContext context) {
    final color = _getRiskColor();
    final label = _getRiskLabel();
    // 0.0 -> -pi/2, 1.0 -> pi/2, but drawing it simply using CustomPaint
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 120, // Half circle
          child: CustomPaint(
            painter: _GaugePainter(riskScore: riskScore, color: color),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "${(riskScore * 100).toInt()}%",
                  style: AppTheme.display.copyWith(color: AppTheme.textPrimary, height: 1.0),
                ).animate().fade(duration: 400.ms).scale(duration: 400.ms, curve: Curves.easeOutBack),
              ),
            ),
          ),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: AppTheme.buttonText.copyWith(color: color),
          ),
        ).animate().slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double riskScore;
  final Color color;

  _GaugePainter({required this.riskScore, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    // Draw background track
    final bgPaint = Paint()
      ..color = AppTheme.dividerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - 10);
    // Draw 180 degree arc
    canvas.drawArc(rect, math.pi, math.pi, false, bgPaint);

    // Draw active track
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    // Arc length based on risk score
    final sweepAngle = math.pi * riskScore;
    canvas.drawArc(rect, math.pi, sweepAngle, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.riskScore != riskScore || oldDelegate.color != color;
  }
}
