import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradepact/core/services/notification_service.dart';
import 'package:tradepact/core/theme/app_theme.dart';
import 'package:tradepact/core/widgets/tradepact_logo.dart';

// Riverpod state for whether onboarding has been completed.
// Default true = skip onboarding if SharedPreferences can't be read.
final onboardingCompleteProvider = StateProvider<bool>((ref) => true);

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _completing = false;

  static const _slides = [
    _Slide(
      icon: Icons.candlestick_chart,
      title: 'Make a pact.\nKeep it.',
      subtitle:
          'The trading journal built for prop traders who take discipline seriously.',
      accentWidget: _TaglineAccent(),
    ),
    _Slide(
      icon: Icons.add_circle_outline,
      title: 'Log every trade.',
      subtitle:
          'Capture entry, SL, TP, mood, and reason in seconds. Track what matters.',
      accentWidget: _TradeLogAccent(),
    ),
    _Slide(
      icon: Icons.mood,
      title: 'Know your patterns.',
      subtitle:
          'See your win rate by mood, session, and pair. Eliminate the habits that cost you.',
      accentWidget: _MoodAccent(),
    ),
    _Slide(
      icon: Icons.business,
      title: 'Built for prop traders.',
      subtitle:
          'Daily loss limits, drawdown tracker, and AI insights aligned with FTMO and Funding Pips rules.',
      accentWidget: _PropFirmAccent(),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
    } catch (_) {
      // SharedPreferences failure is non-fatal — still navigate forward.
      // Onboarding will show again on next cold start, which is acceptable.
    }

    ref.read(onboardingCompleteProvider.notifier).state = true;

    // Schedule notifications now — _initNotifications() already ran before
    // onboarding completed so it skipped scheduling for first-time users.
    try {
      final svc = ref.read(notificationServiceProvider);
      await svc.requestPermission();
      await svc.scheduleDailyReminder();
      await svc.scheduleWeeklyInsightReminder();
    } catch (_) {
      // Notifications are non-critical.
    }

    if (mounted) context.go('/login');
  }

  Future<void> _next() async {
    if (_currentPage < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isLast)
                    TextButton(
                      onPressed: _completing ? null : _complete,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppColors.gold
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: _completing ? null : _next,
                child: _completing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.background,
                        ),
                      )
                    : Text(isLast ? 'Get Started' : 'Next'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide data model
// ---------------------------------------------------------------------------

class _Slide {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget accentWidget;

  const _Slide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentWidget,
  });
}

// ---------------------------------------------------------------------------
// Slide view
// ---------------------------------------------------------------------------

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Accent visual
          SizedBox(height: 180, child: slide.accentWidget),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: AppTextStyles.labelLarge.copyWith(
              fontSize: 28,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accent widgets — illustrative visuals for each slide
// ---------------------------------------------------------------------------

class _TaglineAccent extends StatelessWidget {
  const _TaglineAccent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: TradePactLogo(size: 140),
    );
  }
}

class _TradeLogAccent extends StatelessWidget {
  const _TradeLogAccent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _MockTile(pair: 'XAUUSD', direction: 'BUY', result: 'WIN',
            pnl: '+\$320', color: AppColors.win),
        SizedBox(height: 8),
        _MockTile(pair: 'EURUSD', direction: 'SELL', result: 'LOSS',
            pnl: '-\$85', color: AppColors.loss),
      ],
    );
  }
}

class _MockTile extends StatelessWidget {
  final String pair;
  final String direction;
  final String result;
  final String pnl;
  final Color color;

  const _MockTile({
    required this.pair,
    required this.direction,
    required this.result,
    required this.pnl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              direction == 'BUY' ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(pair,
                style: AppTextStyles.numberSmall.copyWith(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(result,
                style: AppTextStyles.caption
                    .copyWith(color: color, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          Text(pnl,
              style: AppTextStyles.numberSmall
                  .copyWith(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MoodAccent extends StatelessWidget {
  const _MoodAccent();

  static const _data = [
    ('😎 Confident', 68, AppColors.win),
    ('😐 Neutral', 51, AppColors.gold),
    ('😤 Revenge', 22, AppColors.loss),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _data.map((d) {
        final label = d.$1;
        final wr = d.$2;
        final color = d.$3;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha(80)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Text('$wr% WR',
                    style: AppTextStyles.caption.copyWith(color: color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PropFirmAccent extends StatelessWidget {
  const _PropFirmAccent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProgressBar(label: 'Daily Loss', ratio: 0.3, color: AppColors.win),
        SizedBox(height: 12),
        _ProgressBar(label: 'Max Drawdown', ratio: 0.55, color: AppColors.warning),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final String label;
  final double ratio;
  final Color color;

  const _ProgressBar({
    required this.label,
    required this.ratio,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
