import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class DisciplineScoreCard extends StatelessWidget {
  final int score;
  const DisciplineScoreCard({super.key, required this.score});

  Color get _scoreColor {
    if (score > 75) return AppColors.gold;
    if (score >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  String get _label {
    if (score > 75) return 'Elite';
    if (score >= 60) return 'Disciplined';
    if (score >= 50) return 'Developing';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _CircleProgressPainter(
                progress: (score / 100).clamp(0.0, 1.0),
                color: _scoreColor,
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: AppTextStyles.numberMedium.copyWith(
                    color: _scoreColor,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Discipline Score', style: AppTextStyles.labelSmall),
                const SizedBox(height: 4),
                Text(
                  _label,
                  style: AppTextStyles.labelLarge.copyWith(color: _scoreColor),
                ),
                const SizedBox(height: 8),
                _ScoreBreakdown(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _breakdownRow('Followed plan', '40pts'),
        _breakdownRow('No revenge/impulse', '30pts'),
        _breakdownRow('Respected SL', '30pts'),
      ],
    );
  }

  Widget _breakdownRow(String label, String pts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption),
          Text(pts, style: AppTextStyles.caption.copyWith(color: AppColors.gold)),
        ],
      ),
    );
  }
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CircleProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter old) =>
      old.progress != progress || old.color != color;
}
