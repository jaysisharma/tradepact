import 'package:flutter/material.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class StreakWidget extends StatelessWidget {
  final int streak;
  const StreakWidget({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final isActive = streak > 0;
    final color = isActive ? AppColors.gold : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.gold.withAlpha(80) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Day Streak', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: color,
                size: 22,
              ),
              const SizedBox(width: 6),
              Text(
                '$streak',
                style: AppTextStyles.numberMedium.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isActive ? 'Keep it going!' : 'Start your streak',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
