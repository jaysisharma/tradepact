import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/storage_service.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class TradeDetailScreen extends ConsumerWidget {
  /// Initial trade passed from the list. Used as a fallback while Firestore
  /// streams catch up (or if the trade has been deleted).
  final TradeModel trade;
  const TradeDetailScreen({super.key, required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live stream and pick the current version of this trade by ID
    // so edits are reflected immediately without re-pushing the route.
    final liveTrade = ref.watch(tradesProvider).valueOrNull
            ?.firstWhere((t) => t.id == trade.id, orElse: () => trade) ??
        trade;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${liveTrade.pair} · ${liveTrade.direction}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('/add-trade', extra: liveTrade),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.loss),
            onPressed: () => _confirmDelete(context, ref, liveTrade),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultHeader(trade: liveTrade),
            const SizedBox(height: 16),
            if (liveTrade.screenshotUrl.isNotEmpty) ...[
              _ScreenshotCard(url: liveTrade.screenshotUrl),
              const SizedBox(height: 16),
            ],
            _DetailCard(title: 'Prices', children: [
              _row('Entry', _fmt(liveTrade.entry)),
              _row('Stop Loss', _fmt(liveTrade.sl)),
              _row('Take Profit', _fmt(liveTrade.tp)),
              _row('Exit Price', _fmt(liveTrade.exitPrice)),
              _row('Lots', liveTrade.lots.toString()),
            ]),
            const SizedBox(height: 12),
            _DetailCard(title: 'Performance', children: [
              _row('P&L',
                  '${liveTrade.pnl >= 0 ? '+' : ''}\$${liveTrade.pnl.toStringAsFixed(2)}',
                  valueColor: liveTrade.pnl >= 0 ? AppColors.win : AppColors.loss),
              _row('R:R', '1:${liveTrade.rr.toStringAsFixed(2)}'),
              _row('Session', liveTrade.session),
            ]),
            const SizedBox(height: 12),
            _DetailCard(title: 'Psychology', children: [
              _row('Mood', liveTrade.mood),
              _row('Reason', liveTrade.reason),
              _row('Followed Plan', liveTrade.followedPlan ? 'Yes ✓' : 'No ✗',
                  valueColor:
                      liveTrade.followedPlan ? AppColors.win : AppColors.loss),
              _row('Respected SL', liveTrade.respectedSL ? 'Yes ✓' : 'No ✗',
                  valueColor:
                      liveTrade.respectedSL ? AppColors.win : AppColors.loss),
            ]),
            const SizedBox(height: 12),
            _DetailCard(title: 'Discipline Score', children: [
              _row('Score', '${liveTrade.disciplineScore} / 100',
                  valueColor: liveTrade.disciplineScore > 75
                      ? AppColors.gold
                      : liveTrade.disciplineScore >= 50
                          ? AppColors.warning
                          : AppColors.loss),
            ]),
            if (liveTrade.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DetailCard(title: 'Notes', children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(liveTrade.notes, style: AppTextStyles.bodyMedium),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Text(
              'Logged ${DateFormat('EEE, MMM d yyyy · HH:mm').format(liveTrade.timestamp)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v == 0 ? '--' : v.toStringAsFixed(5);

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              child: Text(label, style: AppTextStyles.caption)),
          Text(
            value,
            style: AppTextStyles.numberSmall.copyWith(
              fontSize: 13,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TradeModel liveTrade) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete Trade', style: AppTextStyles.labelLarge),
        content: Text(
          'Delete this ${liveTrade.pair} ${liveTrade.direction} trade? This cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.labelMedium),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style:
                    AppTextStyles.labelMedium.copyWith(color: AppColors.loss)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    try {
      await ref.read(tradeRepositoryProvider).deleteTrade(uid, liveTrade.id);

      // Also remove screenshot from storage if present.
      if (liveTrade.screenshotUrl.isNotEmpty) {
        await ref
            .read(storageServiceProvider)
            .deleteScreenshot(uid, liveTrade.id);
      }

      if (context.mounted) context.go('/trades');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete trade. Please try again.'),
            backgroundColor: AppColors.loss,
          ),
        );
      }
    }
  }
}

class _ResultHeader extends StatelessWidget {
  final TradeModel trade;
  const _ResultHeader({required this.trade});

  Color get _color {
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
    final pnl = trade.pnl;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trade.result,
              style: AppTextStyles.labelLarge.copyWith(color: _color),
            ),
          ),
          const Spacer(),
          Text(
            '${pnl >= 0 ? '+' : ''}\$${pnl.toStringAsFixed(2)}',
            style: AppTextStyles.numberLarge.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  final String url;
  const _ScreenshotCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            color: AppColors.surface,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.broken_image_outlined,
                color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.labelSmall
                .copyWith(letterSpacing: 1.2, fontSize: 10),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}
