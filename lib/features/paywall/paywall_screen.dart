import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/theme/app_theme.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Offerings? _offerings;
  bool _loadingOfferings = true;
  bool _offeringsError = false;
  // 'monthly' | 'annual' | 'restore' | null
  String? _purchasingType;
  String? _error;

  // Which plan card is selected — default to annual (best value)
  String _selected = 'annual';

  static const _features = [
    ('Unlimited trades', Icons.all_inclusive),
    ('Weekly AI insights', Icons.auto_awesome),
    ('Screenshot auto-parse', Icons.document_scanner_outlined),
    ('Mood analytics', Icons.mood),
    ('Prop firm mode', Icons.business),
  ];

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _loadingOfferings = true;
      _offeringsError = false;
    });
    final offerings = await ref.read(premiumServiceProvider).getOfferings();
    if (mounted) {
      setState(() {
        _offerings = offerings;
        _loadingOfferings = false;
        _offeringsError = offerings == null;
        // Auto-correct selection: if annual isn't available, fall back to monthly.
        if (offerings?.current?.annual == null &&
            offerings?.current?.monthly != null) {
          _selected = 'monthly';
        }
      });
    }
  }

  Package? get _monthlyPackage => _offerings?.current?.monthly;
  Package? get _annualPackage => _offerings?.current?.annual;

  String get _monthlyPrice =>
      _monthlyPackage?.storeProduct.priceString ?? '₹299';
  String get _annualPrice =>
      _annualPackage?.storeProduct.priceString ?? '₹1,999';

  Future<void> _purchase() async {
    final package =
        _selected == 'annual' ? _annualPackage : _monthlyPackage;

    if (package == null) {
      setState(() {
        _error =
            'Store unavailable right now. Please check your connection and try again.';
      });
      return;
    }

    setState(() {
      _purchasingType = _selected;
      _error = null;
    });

    final result = await ref.read(premiumServiceProvider).purchase(package);
    if (!mounted) return;

    if (result == AppPurchaseResult.success) {
      ref.invalidate(isPremiumProvider);
      context.pop();
    } else if (result == AppPurchaseResult.error) {
      setState(() {
        _error = 'Purchase failed. Please try again.';
        _purchasingType = null;
      });
    } else {
      setState(() => _purchasingType = null);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _purchasingType = 'restore';
      _error = null;
    });
    final result = await ref.read(premiumServiceProvider).restorePurchases();
    if (!mounted) return;

    if (result == AppPurchaseResult.success) {
      ref.invalidate(isPremiumProvider);
      context.pop();
    } else if (result == AppPurchaseResult.error) {
      setState(() {
        _error = 'No previous purchases found.';
        _purchasingType = null;
      });
    } else {
      setState(() => _purchasingType = null);
    }
  }

  bool get _busy => _purchasingType != null;

  @override
  Widget build(BuildContext context) {
    // If the user is already premium, show confirmation instead of purchase UI.
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;
    if (isPremium) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('TradePact Pro'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified, size: 64, color: AppColors.gold),
                const SizedBox(height: 20),
                Text(
                  'You\'re already Pro!',
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'All features are unlocked. Keep trading with discipline.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TradePact Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _busy ? null : () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.workspace_premium, size: 56, color: AppColors.gold),
            const SizedBox(height: 16),
            Text(
              'Upgrade to Pro',
              style: AppTextStyles.labelLarge.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock every feature and trade with full discipline.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            // Feature list
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: _features
                    .map((f) => _FeatureRow(label: f.$1, icon: f.$2))
                    .toList(),
              ),
            ),
            const SizedBox(height: 28),
            // Plan selector
            if (_loadingOfferings)
              const CircularProgressIndicator(color: AppColors.gold)
            else if (_offeringsError)
              _StoreUnavailableBanner(onRetry: _loadOfferings)
            else ...[
              _PlanCard(
                label: 'Annual',
                price: _annualPrice,
                subtitle: 'Billed yearly · Save ~44%',
                badge: 'Best Value',
                selected: _selected == 'annual',
                disabled: _busy,
                onTap: () => setState(() { _selected = 'annual'; _error = null; }),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                label: 'Monthly',
                price: _monthlyPrice,
                subtitle: 'Billed monthly · Cancel anytime',
                badge: null,
                selected: _selected == 'monthly',
                disabled: _busy,
                onTap: () => setState(() { _selected = 'monthly'; _error = null; }),
              ),
              const SizedBox(height: 24),
              // CTA button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _busy ? null : _purchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor: AppColors.gold.withAlpha(80),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _purchasingType == 'monthly' ||
                          _purchasingType == 'annual'
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.background,
                          ),
                        )
                      : Text(
                          'Get Pro · ${_selected == 'annual' ? '$_annualPrice/yr' : '$_monthlyPrice/mo'}',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.background,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.loss),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy ? null : _restore,
              child: _purchasingType == 'restore'
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold),
                    )
                  : Text(
                      'Restore Purchases',
                      style:
                          AppTextStyles.caption.copyWith(color: AppColors.gold),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cancel anytime from your store account settings.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _FeatureRow({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gold),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.labelMedium),
          const Spacer(),
          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.win),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final String subtitle;
  final String? badge;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _PlanCard({
    required this.label,
    required this.price,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withAlpha(18)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: selected
                            ? AppColors.gold
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badge!,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.background,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
            const Spacer(),
            Text(
              price,
              style: AppTextStyles.numberSmall.copyWith(
                color: selected ? AppColors.gold : AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreUnavailableBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _StoreUnavailableBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary, size: 32),
          const SizedBox(height: 8),
          Text(
            'Store unavailable',
            style: AppTextStyles.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Check your connection and tap retry.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: AppTextStyles.caption.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
