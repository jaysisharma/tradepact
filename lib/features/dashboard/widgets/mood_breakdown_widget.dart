import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

/// Win-rate breakdown per mood, shown as a row of chips.
class MoodBreakdownWidget extends ConsumerWidget {
  const MoodBreakdownWidget({super.key});

  static const _moods = [
    ('confident', '😎'),
    ('neutral', '😐'),
    ('anxious', '😰'),
    ('bored', '😑'),
    ('revenge', '😤'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;
    if (!isPremium) return _LockedMoodCard();

    final tradesAsync = ref.watch(tradesProvider);

    return tradesAsync.when(
      data: (trades) {
        // Only render chips for moods that have at least one trade.
        final chips = _moods
            .map((m) {
              final mood = m.$1;
              final emoji = m.$2;
              final moodTrades = trades.where((t) => t.mood == mood).toList();
              if (moodTrades.isEmpty) return null;
              final wins =
                  moodTrades.where((t) => t.result == 'WIN').length;
              final wr = (wins / moodTrades.length * 100).round();
              return _MoodChip(
                  emoji: emoji, mood: mood, winRate: wr, count: moodTrades.length);
            })
            .whereType<_MoodChip>()
            .toList();

        if (chips.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mood Analytics', style: AppTextStyles.labelSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final String emoji;
  final String mood;
  final int winRate;
  final int count;

  const _MoodChip({
    required this.emoji,
    required this.mood,
    required this.winRate,
    required this.count,
  });

  Color get _wrColor {
    if (winRate >= 60) return AppColors.win;
    if (winRate >= 40) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    final label =
        '${mood[0].toUpperCase()}${mood.substring(1)}: $winRate% WR';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _wrColor.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: _wrColor),
          ),
        ],
      ),
    );
  }
}

class _LockedMoodCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/paywall'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline,
                color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mood Analytics', style: AppTextStyles.labelSmall),
                  const SizedBox(height: 2),
                  Text('Upgrade to Pro to see win rate per mood.',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Text(
              'Upgrade',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.gold, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
