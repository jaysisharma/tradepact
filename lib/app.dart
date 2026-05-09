import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/features/auth/login_screen.dart';
import 'package:tradepact/features/dashboard/dashboard_screen.dart';
import 'package:tradepact/features/insights/insights_screen.dart';
import 'package:tradepact/features/onboarding/onboarding_screen.dart';
import 'package:tradepact/features/paywall/paywall_screen.dart';
import 'package:tradepact/features/settings/prop_firm_setup_screen.dart';
import 'package:tradepact/features/settings/settings_screen.dart';
import 'package:tradepact/features/trade_log/add_trade_screen.dart';
import 'package:tradepact/features/trade_log/trade_detail_screen.dart';
import 'package:tradepact/features/trade_log/trade_list_screen.dart';

/// Exposed so [NotificationService] can navigate from outside the widget tree.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingComplete = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final location = state.matchedLocation;

      // 1. Onboarding is top priority.
      // If not completed, force user to /onboarding regardless of login status.
      if (!onboardingComplete) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // 2. If onboarding is complete, prevent user from being stuck on /onboarding.
      if (location == '/onboarding') {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      // 3. Authentication guards for all other routes.
      final isLoginPage = location == '/login';
      if (!isLoggedIn && !isLoginPage) {
        return '/login';
      }
      if (isLoggedIn && isLoginPage) {
        return '/dashboard';
      }

      // No redirect needed.
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Paywall has no bottom nav.
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => _AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/trades',
            builder: (context, state) => const TradeListScreen(),
          ),
          GoRoute(
            path: '/add-trade',
            builder: (context, state) {
              final trade = state.extra as TradeModel?;
              return AddTradeScreen(editingTrade: trade);
            },
          ),
          GoRoute(
            path: '/trade-detail/:id',
            builder: (context, state) {
              final trade = state.extra as TradeModel?;
              if (trade == null) {
                // Fallback if navigated without extra (e.g. deep link).
                return const Scaffold(
                  body: Center(child: Text('Trade not found.')),
                );
              }
              return TradeDetailScreen(trade: trade);
            },
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/prop-firm-setup',
            builder: (context, state) => const PropFirmSetupScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AppShell extends ConsumerWidget {
  final Widget child;

  const _AppShell({required this.child});

  static const _tabs = [
    '/dashboard',
    '/trades',
    '/add-trade',
    '/insights',
    '/settings',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexOf(location).clamp(0, _tabs.length - 1);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => context.go(_tabs[index]),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_outlined),
            activeIcon: Icon(Icons.list),
            label: 'Trades',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Add Trade',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Insights',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
