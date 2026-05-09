import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:tradepact/core/models/insight_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/gemini_service.dart';
import 'package:tradepact/core/services/insights_repository.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/services/trade_repository.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  bool _generating = false;
  String? _genError;

  Future<void> _generate() async {
    final isPremium = ref.read(isPremiumProvider).valueOrNull ?? false;
    if (!isPremium) {
      context.push('/paywall');
      return;
    }

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    setState(() {
      _generating = true;
      _genError = null;
    });

    try {
      // Use last 7 days of trades as context.
      final allTrades = ref.read(tradesProvider).valueOrNull ?? [];
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      final recentTrades =
          allTrades.where((t) => t.timestamp.isAfter(cutoff)).toList();

      if (recentTrades.isEmpty) {
        setState(() {
          _genError = 'No trades in the last 7 days to analyze.';
          _generating = false;
        });
        return;
      }

      final summary = await ref
          .read(geminiServiceProvider)
          .generateWeeklyInsight(recentTrades);

      if (summary == null) {
        setState(() {
          _genError =
              'Could not generate insight. Check your Gemini API key.';
          _generating = false;
        });
        return;
      }

      final insight = InsightModel(
        weekId: InsightsRepository.weekIdFor(DateTime.now()),
        summary: summary,
        generatedAt: DateTime.now(),
      );

      await ref.read(insightsRepositoryProvider).saveInsight(uid, insight);
    } catch (e) {
      setState(() => _genError = 'Error: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context, ) {
    final insightAsync = ref.watch(currentWeekInsightProvider);
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Insights'),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.gold),
            onPressed: _generating ? null : _generate,
            tooltip: 'Regenerate this week\'s insight',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(currentWeekInsightProvider);
        },
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isPremium) _PremiumBanner(),
            const SizedBox(height: 4),
            insightAsync.when(
              data: (insight) {
                if (insight == null) {
                  return _EmptyInsightState(
                    generating: _generating,
                    error: _genError,
                    onGenerate: _generate,
                  );
                }
                return _InsightCard(
                  insight: insight,
                  generating: _generating,
                  error: _genError,
                  onRefresh: _generate,
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e', style: AppTextStyles.labelMedium),
              ),
            ),
          ],
        ),
        ),   // SingleChildScrollView
      ),     // RefreshIndicator
    );
  }
}

// ---------------------------------------------------------------------------
// Premium banner
// ---------------------------------------------------------------------------

class _PremiumBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI Insights require TradePact Pro.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.gold),
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Text(
              'Upgrade',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state (no insight yet)
// ---------------------------------------------------------------------------

class _EmptyInsightState extends StatelessWidget {
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;

  const _EmptyInsightState({
    required this.generating,
    required this.error,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome,
                size: 56, color: AppColors.gold),
            const SizedBox(height: 16),
            Text('No insight for this week yet',
                style: AppTextStyles.labelLarge),
            const SizedBox(height: 8),
            Text(
              'Generate a weekly analysis based on your last 7 days.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!,
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.loss),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: generating ? null : onGenerate,
              icon: generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.background))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                  generating ? 'Analyzing...' : 'Generate Insight'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insight card
// ---------------------------------------------------------------------------

class _InsightCard extends StatelessWidget {
  final InsightModel insight;
  final bool generating;
  final String? error;
  final VoidCallback onRefresh;

  const _InsightCard({
    required this.insight,
    required this.generating,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEE, MMM d · HH:mm')
        .format(insight.generatedAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withAlpha(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      size: 16, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Weekly Analysis',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.gold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...insight.bullets.map((bullet) => _BulletPoint(text: bullet)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.access_time,
                size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text('Generated $dateStr', style: AppTextStyles.caption),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!,
              style: AppTextStyles.caption.copyWith(color: AppColors.loss)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BulletPoint extends StatelessWidget {
  final String text;
  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    // Strip leading "• " if Gemini included it; we render our own bullet.
    final cleaned = text.startsWith('• ') ? text.substring(2) : text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(cleaned, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}
