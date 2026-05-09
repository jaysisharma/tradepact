import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/user_profile_model.dart';
import 'package:tradepact/core/services/profile_repository.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

/// Dashboard card showing prop firm risk limits and how close the trader is.
class PropFirmBar extends ConsumerWidget {
  const PropFirmBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final statsAsync = ref.watch(userStatsProvider);
    final todayPnl = ref.watch(todayPnlProvider);

    return profileAsync.when(
      data: (profile) {
        // Only render when the user has configured a prop firm.
        if (profile == null ||
            (profile.dailyLossLimit == 0 && profile.maxDrawdown == 0)) {
          return const SizedBox.shrink();
        }
        final totalPnl = statsAsync.valueOrNull?.totalPnl ?? 0.0;
        return _PropFirmBarBody(
          profile: profile,
          todayPnl: todayPnl,
          totalPnl: totalPnl,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PropFirmBarBody extends StatelessWidget {
  final UserProfileModel profile;
  final double todayPnl;
  final double totalPnl;

  const _PropFirmBarBody({
    required this.profile,
    required this.todayPnl,
    required this.totalPnl,
  });

  @override
  Widget build(BuildContext context) {
    final firm = profile.propFirm.isNotEmpty ? profile.propFirm : 'Prop Firm';

    // Daily loss used (positive number = loss consumed).
    final dailyLoss = todayPnl < 0 ? todayPnl.abs() : 0.0;
    final dailyLimit = profile.dailyLossLimit;

    // Drawdown = total loss from start (positive number).
    final drawdown = totalPnl < 0 ? totalPnl.abs() : 0.0;
    final maxDrawdown = profile.maxDrawdown;

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
          Row(
            children: [
              const Icon(Icons.business, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Text(firm, style: AppTextStyles.labelSmall.copyWith(color: AppColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          if (dailyLimit > 0) ...[
            _LimitBar(
              label: 'Daily Loss',
              used: dailyLoss,
              limit: dailyLimit,
            ),
            const SizedBox(height: 10),
          ],
          if (maxDrawdown > 0)
            _LimitBar(
              label: 'Max Drawdown',
              used: drawdown,
              limit: maxDrawdown,
            ),
        ],
      ),
    );
  }
}

class _LimitBar extends StatelessWidget {
  final String label;
  final double used;
  final double limit;

  const _LimitBar({
    required this.label,
    required this.used,
    required this.limit,
  });

  double get _ratio => (used / limit).clamp(0.0, 1.0);

  /// Within 20 % of the limit = warning zone.
  bool get _isWarning => _ratio >= 0.8;

  Color get _barColor {
    if (_ratio >= 1.0) return AppColors.loss;
    if (_isWarning) return AppColors.warning;
    return AppColors.win;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (limit - used).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.caption),
            Text(
              '\$${used.toStringAsFixed(0)} / \$${limit.toStringAsFixed(0)}',
              style: AppTextStyles.caption.copyWith(
                color: _barColor,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _ratio,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(_barColor),
            minHeight: 6,
          ),
        ),
        if (_isWarning && remaining > 0) ...[
          const SizedBox(height: 4),
          Text(
            '⚠️ You are \$${remaining.toStringAsFixed(0)} away from your $label limit',
            style: AppTextStyles.caption.copyWith(color: AppColors.warning),
          ),
        ],
      ],
    );
  }
}
