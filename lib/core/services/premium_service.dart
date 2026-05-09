import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:tradepact/core/config/env_config.dart';
import 'package:tradepact/core/services/auth_service.dart';

enum AppPurchaseResult {
  success,
  cancelled,
  error,
}

final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService();
});

/// Streams the current premium status. Stays false until RevenueCat confirms.
final isPremiumProvider = StreamProvider<bool>((ref) {
  // Play Store reviewer account — unconditional full access.
  final email = ref.watch(authStateProvider).valueOrNull?.email;
  if (email == 'tester@tradepact.com') {
    return Stream.value(true);
  }

  final controller = StreamController<bool>();

  Purchases.addCustomerInfoUpdateListener((info) {
    if (!controller.isClosed) {
      controller.add(
        info.entitlements.active.containsKey(PremiumService.entitlementId),
      );
    }
  });

  // Seed with current value immediately.
  Purchases.getCustomerInfo().then((info) {
    if (!controller.isClosed) {
      controller.add(
        info.entitlements.active.containsKey(PremiumService.entitlementId),
      );
    }
  }).catchError((_) {
    if (!controller.isClosed) controller.add(false);
  });

  ref.onDispose(controller.close);

  return controller.stream;
});

class PremiumService {
  static const entitlementId = 'TradePact Pro';

  /// Call once from main() after Firebase is initialized.
  static Future<void> initialize() async {
    if (!EnvConfig.hasRevenueCatKey) {
      debugPrint('[PremiumService] RevenueCat API key is missing. '
          'Run with --dart-define=REVENUECAT_API_KEY=your_key');
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);
      final config = PurchasesConfiguration(EnvConfig.revenueCatApiKey);
      await Purchases.configure(config);
    } catch (_) {
      // Silently ignore in debug if initialization fails.
    }
  }

  /// Syncs RevenueCat with Firebase UID on login.
  Future<void> logIn(String uid) async {
    try {
      await Purchases.logIn(uid);
    } catch (_) {
      // Silently ignore login failures.
    }
  }

  /// Clears RevenueCat status on logout.
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {
      // Silently ignore logout failures.
    }
  }

  /// Returns true if the current user has an active premium entitlement.
  Future<bool> checkPremiumStatus() async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementId);
    } catch (_) {
      return false;
    }
  }

  /// Loads the current offerings from RevenueCat.
  /// Returns null if unavailable (e.g., placeholder key or no network).
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Initiates the purchase flow for [package].
  /// Returns a [AppPurchaseResult] indicating the outcome.
  Future<AppPurchaseResult> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final hasEntitlement =
          result.customerInfo.entitlements.active.containsKey(entitlementId);

      if (hasEntitlement) {
        return AppPurchaseResult.success;
      } else {
        // This is where "success but failed" usually happens if the ID is wrong.
        debugPrint(
            '[PremiumService] Purchase SUCCESS, but entitlement "$entitlementId" was NOT found.');
        debugPrint(
            '[PremiumService] Active entitlements: ${result.customerInfo.entitlements.active.keys}');
        return AppPurchaseResult.error;
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[PremiumService] Purchase cancelled by user.');
        return AppPurchaseResult.cancelled;
      }
      debugPrint('[PremiumService] Purchase error: ${e.message}');
      return AppPurchaseResult.error;
    } catch (e) {
      debugPrint('[PremiumService] Unknown purchase error: $e');
      return AppPurchaseResult.error;
    }
  }

  /// Restores previous purchases.
  /// Returns a [AppPurchaseResult] indicating the outcome.
  Future<AppPurchaseResult> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final hasEntitlement = info.entitlements.active.containsKey(entitlementId);

      if (hasEntitlement) {
        return AppPurchaseResult.success;
      } else {
        debugPrint('[PremiumService] Restore success, but no active entitlement.');
        return AppPurchaseResult.error;
      }
    } catch (e) {
      debugPrint('[PremiumService] Restore error: $e');
      return AppPurchaseResult.error;
    }
  }
}
