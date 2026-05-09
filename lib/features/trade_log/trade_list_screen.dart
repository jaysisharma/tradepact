import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

/// Currently selected mood filter. Null = show all.
final moodFilterProvider = StateProvider<String?>((ref) => null);

class TradeListScreen extends ConsumerWidget {
  const TradeListScreen({super.key});

  static const _moods = [
    (null, 'All'),
    ('confident', '😎 Confident'),
    ('neutral', '😐 Neutral'),
    ('anxious', '😰 Anxious'),
    ('bored', '😑 Bored'),
    ('revenge', '😤 Revenge'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradesAsync = ref.watch(tradesProvider);
    final selectedMood = ref.watch(moodFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trade History'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood filter chips
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final mood = _moods[i].$1;
                final label = _moods[i].$2;
                final selected = selectedMood == mood;
                return FilterChip(
                  label: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                  selected: selected,
                  onSelected: (_) {
                    ref.read(moodFilterProvider.notifier).state = mood;
                  },
                  backgroundColor: AppColors.surfaceVariant,
                  selectedColor: AppColors.gold,
                  checkmarkColor: AppColors.background,
                  side: BorderSide(
                    color: selected ? AppColors.gold : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: tradesAsync.when(
              data: (trades) {
                final filtered = selectedMood == null
                    ? trades
                    : trades.where((t) => t.mood == selectedMood).toList();

                return RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref.invalidate(tradesProvider);
                    await ref.read(tradesProvider.future);
                  },
                  child: filtered.isEmpty
                      ? _EmptyList(isFiltered: selectedMood != null)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _TradeTile(trade: filtered[index]),
                        ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (e, _) => _ErrorState(
                message: 'Could not load trades.\n$e',
                onRetry: () => ref.invalidate(tradesProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Single empty-list widget used by both filtered and unfiltered paths.
// Must be inside a scrollable so RefreshIndicator can trigger on it.
class _EmptyList extends StatelessWidget {
  final bool isFiltered;
  const _EmptyList({required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.candlestick_chart,
                    size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  isFiltered ? 'No trades with this mood' : 'No trades yet',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  isFiltered
                      ? 'Try a different filter or log a trade with this mood.'
                      : 'Log your first trade to start tracking.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.loss),
            const SizedBox(height: 16),
            Text(message,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeTile extends StatelessWidget {
  final TradeModel trade;
  const _TradeTile({required this.trade});

  Color get _resultColor {
    switch (trade.result) {
      case 'WIN':
        return AppColors.win;
      case 'LOSS':
        return AppColors.loss;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, HH:mm').format(trade.timestamp);
    final pnlStr =
        '${trade.pnl >= 0 ? '+' : ''}\$${trade.pnl.toStringAsFixed(2)}';

    return GestureDetector(
      onTap: () => context.push('/trade-detail/${trade.id}', extra: trade),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _DirectionBadge(direction: trade.direction),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(trade.pair,
                          style: AppTextStyles.numberSmall
                              .copyWith(fontSize: 15)),
                      const SizedBox(width: 8),
                      _ResultBadge(result: trade.result, color: _resultColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(dateStr, style: AppTextStyles.caption),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pnlStr,
                  style: AppTextStyles.numberSmall.copyWith(
                    color: _resultColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trade.rr > 0 ? '1:${trade.rr.toStringAsFixed(1)}' : '—',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  final String direction;
  const _DirectionBadge({required this.direction});

  @override
  Widget build(BuildContext context) {
    final isBuy = direction == 'BUY';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: (isBuy ? AppColors.win : AppColors.loss).withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isBuy ? Icons.arrow_upward : Icons.arrow_downward,
        color: isBuy ? AppColors.win : AppColors.loss,
        size: 22,
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final String result;
  final Color color;
  const _ResultBadge({required this.result, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        result,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
