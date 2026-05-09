import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/user_profile_model.dart';
import 'package:tradepact/core/services/profile_repository.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';
import 'package:tradepact/features/dashboard/widgets/discipline_score_card.dart';
import 'package:tradepact/features/dashboard/widgets/mood_breakdown_widget.dart';
import 'package:tradepact/features/dashboard/widgets/prop_firm_bar.dart';
import 'package:tradepact/features/dashboard/widgets/streak_widget.dart';
import 'package:tradepact/core/widgets/banner_ad_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TradePact'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text('Make a pact. Keep it.', style: AppTextStyles.caption),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) => _DashboardBody(stats: stats),
        loading: () => const _DashboardSkeleton(),
        error: (e, _) => _ErrorState(message: 'Could not load stats.\n$e'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — shown when data is ready
// ---------------------------------------------------------------------------

class _DashboardBody extends ConsumerWidget {
  final UserStatsModel stats;
  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pnlPositive = stats.totalPnl >= 0;

    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(userStatsProvider);
        ref.invalidate(tradesProvider);
        ref.invalidate(userProfileProvider);
        await ref.read(userStatsProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Total Trades',
                    value: stats.totalTrades.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Win Rate',
                    value: '${stats.winRate.toStringAsFixed(1)}%',
                    valueColor:
                        stats.winRate >= 50 ? AppColors.win : AppColors.loss,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatCard(
              label: 'Total P&L',
              value:
                  '${pnlPositive ? '+' : ''}\$${stats.totalPnl.toStringAsFixed(2)}',
              valueColor: pnlPositive ? AppColors.win : AppColors.loss,
              large: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StreakWidget(streak: stats.currentStreak)),
                const SizedBox(width: 12),
                Expanded(
                    child: _WinsLossesCard(
                        wins: stats.wins, losses: stats.losses)),
              ],
            ),
            const SizedBox(height: 12),
            DisciplineScoreCard(score: stats.disciplineScore),
            const SizedBox(height: 12),
            const PropFirmBar(),
            const SizedBox(height: 12),
            const MoodBreakdownWidget(),
            const SizedBox(height: 24),
            const BannerAdWidget(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton — shown while loading
// ---------------------------------------------------------------------------

class _DashboardSkeleton extends StatefulWidget {
  const _DashboardSkeleton();

  @override
  State<_DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<_DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation =
        Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        final color =
            AppColors.surface.withValues(alpha: _animation.value);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _bone(height: 76, color: color)),
                  const SizedBox(width: 12),
                  Expanded(child: _bone(height: 76, color: color)),
                ],
              ),
              const SizedBox(height: 12),
              _bone(height: 84, color: color),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _bone(height: 76, color: color)),
                  const SizedBox(width: 12),
                  Expanded(child: _bone(height: 76, color: color)),
                ],
              ),
              const SizedBox(height: 12),
              _bone(height: 108, color: color),
            ],
          ),
        );
      },
    );
  }

  Widget _bone({required double height, required Color color}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends ConsumerWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.loss),
            const SizedBox(height: 16),
            Text(
              message,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                ref.invalidate(userStatsProvider);
                ref.invalidate(tradesProvider);
              },
              child: Text(
                'Retry',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared stat widgets
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool large;

  const _StatCard({
    required this.label,
    required this.value,
    this.valueColor,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = large
        ? AppTextStyles.numberLarge
            .copyWith(color: valueColor ?? AppColors.textPrimary)
        : AppTextStyles.numberMedium
            .copyWith(color: valueColor ?? AppColors.textPrimary);

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
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}

class _WinsLossesCard extends StatelessWidget {
  final int wins;
  final int losses;
  const _WinsLossesCard({required this.wins, required this.losses});

  @override
  Widget build(BuildContext context) {
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
          Text('W / L', style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$wins',
                  style: AppTextStyles.numberMedium
                      .copyWith(color: AppColors.win)),
              Text(' / ',
                  style: AppTextStyles.numberMedium
                      .copyWith(color: AppColors.textSecondary)),
              Text('$losses',
                  style: AppTextStyles.numberMedium
                      .copyWith(color: AppColors.loss)),
            ],
          ),
        ],
      ),
    );
  }
}
