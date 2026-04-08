import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:heartech/core/theme/app_theme.dart';
import 'package:heartech/shared/widgets/risk_badge.dart';

/// Circular animated risk gauge with score number inside and RiskBadge below.
class RiskGauge extends StatefulWidget {
  final int score; // 0-100
  final String riskLevel;
  final double size;
  final bool animate;

  const RiskGauge({
    super.key,
    required this.score,
    required this.riskLevel,
    this.size = 160,
    this.animate = true,
  });

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.score.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(RiskGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: 0,
        end: widget.score.toDouble(),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ));
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = HearTechColors.riskColor(widget.riskLevel);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final currentScore = _animation.value;
            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background + progress arc
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: _GaugePainter(
                      progress: currentScore / 100,
                      color: color,
                      backgroundColor: HearTechColors.paleTeal,
                      strokeWidth: widget.size * 0.08,
                    ),
                  ),
                  // Score number in center
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentScore.round().toString(),
                        style: HearTechTextStyles.bigNumber(color: color),
                      ),
                      Text(
                        'out of 100',
                        style: HearTechTextStyles.caption(),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Risk badge below the circle
        RiskBadge(riskLevel: widget.riskLevel),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _GaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi * 0.75; // Start from bottom-left
    const sweepAngle = math.pi * 1.5; // 270 degrees

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
