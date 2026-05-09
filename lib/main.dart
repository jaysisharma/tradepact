import 'package:firebase_core/firebase_core.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradepact/app.dart';
import 'package:tradepact/core/services/notification_service.dart';
import 'package:tradepact/core/services/premium_service.dart';
import 'package:tradepact/core/theme/app_theme.dart';
import 'package:tradepact/features/onboarding/onboarding_screen.dart';
import 'package:tradepact/firebase_options.dart';
import 'package:tradepact/core/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Read onboarding flag before runApp so the router can use it.
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  await PremiumService.initialize();
  await AdService().init();

  runApp(
    ProviderScope(
      overrides: [
        // Seed the onboarding state from SharedPreferences.
        onboardingCompleteProvider
            .overrideWith((ref) => onboardingComplete),
      ],
      child: const TradePactApp(),
    ),
  );
}

class TradePactApp extends ConsumerStatefulWidget {
  const TradePactApp({super.key});

  @override
  ConsumerState<TradePactApp> createState() => _TradePactAppState();
}

class _TradePactAppState extends ConsumerState<TradePactApp> {
  @override
  void initState() {
    super.initState();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    try {
      final service = ref.read(notificationServiceProvider);
      await service.initialize(
        onNotificationTap: (route) {
          // Navigate using the global router key once the tree is ready.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            rootNavigatorKey.currentContext?.go(route);
          });
        },
      );

      // Request permission on first launch (after onboarding).
      final onboardingDone = ref.read(onboardingCompleteProvider);
      if (onboardingDone) {
        await service.requestPermission();
        await service.scheduleDailyReminder();
        await service.scheduleWeeklyInsightReminder();
      }
    } catch (_) {
      // Notifications are non-critical — silently ignore init failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync RevenueCat with Firebase UID to ensure premium status is 
    // account-specific (not just device-specific).
    ref.listen(authStateProvider, (previous, next) async {
      final user = next.asData?.value;
      if (user != null) {
        await ref.read(premiumServiceProvider).logIn(user.uid);
      } else {
        await ref.read(premiumServiceProvider).logOut();
      }
      // Force a fresh fetch of premium status after syncing account IDs.
      ref.invalidate(isPremiumProvider);
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TradePact',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}
