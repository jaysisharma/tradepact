import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final adServiceProvider = Provider<AdService>((ref) {
  return AdService();
});

class AdService {
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('[AdService] Mobile Ads initialized');
    } catch (e) {
      debugPrint('[AdService] Error initializing Mobile Ads: $e');
    }
  }

  /// Returns the appropriate Ad Unit ID based on the platform.
  /// Currently using Google's sample IDs for testing.
  String get bannerAdUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'ca-app-pub-3586807929660560/6663047665'; // Real Android Banner
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS Sample
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Creates a BannerAd instance.
  BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
    );
  }
}
