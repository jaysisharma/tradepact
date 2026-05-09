# Tradepact — Trading Journal App

## What This Is
A Flutter mobile app for prop traders to log trades, track discipline,
and get AI insights. Target users: Prop firm traders (Funding Pips, FTMO)
trading XAUUSD and forex pairs.

## Tagline
Make a pact. Keep it.

## Tech Stack
- Flutter (latest stable)
- Firebase Auth (Google Sign-in)
- Firestore (database)
- Firebase Storage (chart screenshots)
- Gemini 1.5 Flash (AI insights + screenshot parsing)
- RevenueCat (subscriptions)
- Riverpod (state management)

## Package Name
com.jaysi.tradepact

## Folder Structure
lib/
  main.dart
  app.dart
  features/
    auth/
      login_screen.dart
    dashboard/
      dashboard_screen.dart
      widgets/
        discipline_score_card.dart
        streak_widget.dart
        prop_firm_bar.dart
    trade_log/
      add_trade_screen.dart
      trade_list_screen.dart
      trade_detail_screen.dart
    insights/
      insights_screen.dart
    settings/
      settings_screen.dart
  core/
    services/
      auth_service.dart
      trade_repository.dart
      gemini_service.dart
      revenuecat_service.dart
    models/
      trade_model.dart
      user_profile_model.dart
    theme/
      app_theme.dart

## Design System
- Dark theme only, NO light mode
- Background: #0d0d0d
- Gold accent: #c9a84c
- Error/loss: #e05c5c
- Win: #4caf82
- Font: JetBrains Mono for numbers/data, Inter for UI text
- Rounded corners: 12px
- No gradients, flat dark surfaces

## Code Rules
- Always use Riverpod for state management
- All Firestore calls go through repository classes only
- Never put business logic in widgets
- Models always have fromJson/toJson/copyWith
- Use GoRouter for navigation
- All screens use ConsumerWidget

## Firestore Schema
users/{uid}/
  profile: { name, email, propFirm, accountSize, dailyLossLimit, maxDrawdown }
  stats: { totalTrades, wins, losses, totalPnl, currentStreak, disciplineScore }

users/{uid}/trades/{tradeId}/
  pair: "XAUUSD"
  direction: "BUY" | "SELL"
  entry: double
  sl: double
  tp: double
  exitPrice: double
  result: "WIN" | "LOSS" | "BE"
  pnl: double
  rr: double
  lots: double
  mood: "confident" | "anxious" | "bored" | "revenge" | "neutral"
  reason: "setup" | "impulse" | "FOMO" | "other"
  followedPlan: bool
  respectedSL: bool
  session: "London" | "New York" | "Asia" | "Other"
  screenshotUrl: string
  notes: string
  timestamp: Timestamp

## Discipline Score Formula
- Followed plan: 40% weight
- No revenge/impulse mood: 30% weight  
- Respected SL: 30% weight
- Score out of 100

## Completed Sprints

### Sprint 1 ✅ — Foundation
Goal: user can sign in, add a trade, and see it listed.
- pubspec.yaml, all models, AuthService, TradeRepository, app_theme
- LoginScreen, AddTradeScreen (full form), TradeListScreen, DashboardScreen
- Bottom nav, GoRouter wiring

### Sprint 2 ✅ — Discipline, Streaks, Mood, Prop Firm
1. DisciplineService — calculateDisciplineScore() averaging per-trade scores
   - Colors: <50 red, 50-75 orange, >75 gold
   - Score updated in Firestore after every addTrade/updateTrade
2. Streak Tracker — consecutive days with ≥1 trade (resets if day skipped)
   - Shown as "Day Streak" on Dashboard with fire icon
3. Mood Analytics
   - Filter chips on TradeListScreen (moodFilterProvider)
   - MoodBreakdownWidget on Dashboard: win rate per mood as chips
4. Prop Firm Mode
   - PropFirmSetupScreen at settings/prop_firm_setup_screen.dart
   - ProfileRepository saves to users/{uid}/profile/data
   - PropFirmBar on Dashboard: daily P&L and drawdown progress bars
     with ⚠️ warning at 80% of limit
   - Settings tile shows configured firm name; navigates to /prop-firm-setup

### Sprint 3 ✅ — AI, Screenshots, Paywall, Trade Detail
1. Screenshot Upload + Gemini Auto-Parse
   - image_picker (camera + gallery) on AddTradeScreen
   - StorageService uploads to users/{uid}/screenshots/{tradeId}.jpg
   - GeminiService.parseChartScreenshot() → JSON fields auto-fill form
   - Screenshot thumbnail in AddTradeScreen + TradeDetailScreen
   - Gated behind premium check (redirects to PaywallScreen)
2. Weekly AI Insight Generation
   - GeminiService.generateWeeklyInsight() → 3 bullet points
   - InsightsRepository saves to users/{uid}/insights/{weekId}
   - InsightsScreen: insight card, refresh button, last generated date
   - Gated behind premium
3. RevenueCat Paywall
   - PremiumService initializes RevenueCat in main.dart
   - isPremiumProvider (StreamProvider from customerInfoStream)
   - PaywallScreen: Monthly + Lifetime options, feature list, restore
   - Free tier: 20 trade limit → redirects to paywall on 21st trade
   - Gated features: screenshot parsing, AI insights, mood analytics
4. TradeDetailScreen — all fields, edit button, delete with confirm, screenshot
5. AddTradeScreen — ConsumerStatefulWidget, edit mode pre-fill via GoRouter extra,
   TextEditingControllers for correct pre-fill, autoDispose provider

### Sprint 4 ✅ — Polish + Ship
1. FCM Notifications
   - NotificationService initializes FCM + flutter_local_notifications
   - Daily reminder at 8PM every day ("Log your trades for today 📊")
   - Weekly insight reminder every Sunday at 10AM ("Your weekly report is ready 📈")
   - Notification tap → navigates to /trades or /insights via rootNavigatorKey
   - Settings → Notifications tile opens enable dialog
2. Onboarding Flow
   - OnboardingScreen: 4 slides with PageView (tagline, trade log, mood, prop firm)
   - SharedPreferences flag 'onboarding_complete' — shown only on first launch
   - onboardingCompleteProvider seeded from SharedPreferences in main()
   - GoRouter redirect sends new users to /onboarding before /login
   - Skip + Get Started buttons; animated dot indicators
3. Play Store Assets
   - assets/store/store_readme.md — app icon spec (512px, gold candlesticks on #0d0d0d)
   - assets/store/listing.md — full Play Store listing with description, keywords, category
4. Final Polish
   - DashboardScreen: animated pulsing skeleton while loading; RefreshIndicator
   - TradeListScreen: RefreshIndicator with AlwaysScrollableScrollPhysics
   - InsightsScreen: RefreshIndicator
   - AddTradeScreen: HapticFeedback.mediumImpact() on successful trade save
   - SettingsScreen: app version via package_info_plus; About card (Jaysi Sharma, @tradepact)
   - Notifications tile wired to enable dialog in settings
   - ErrorState widget on Dashboard for graceful failure

## Post-Launch Notes

### Platform Config Required Before Release
1. **AndroidManifest.xml** — add:
   ```xml
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   ```
   Add `<receiver>` for `BootReceiver` (flutter_local_notifications docs).
2. **iOS Info.plist** — add `NSUserNotificationsUsageDescription` key.
3. **RevenueCat** — replace `'rcb_placeholder_key'` in `PremiumService` with real key.
4. **Gemini** — replace `'YOUR_GEMINI_API_KEY'` in `GeminiService` with real key.
   Use server-side proxy in production to keep key off the device.
5. **App icon** — generate with `flutter_launcher_icons` per `assets/store/store_readme.md`.
6. **Google Services** — `google-services.json` already present (Sprint 1). Keep out of git.

### API Keys Checklist
- [ ] Gemini API key (Google AI Studio)
- [ ] RevenueCat public API key (dashboard.revenuecat.com)
- [ ] Firebase project — Firestore rules deployed (see root README)

### Next Steps (Post-Launch)
- Performance analytics screen (equity curve chart via fl_chart)
- Trade tagging (breakout, news, scalp) + filter
- CSV export from Settings
- Deep-link support for /trade-detail/:id
- Android widget (day streak + P&L on home screen)

## Dependencies to Add
firebase_core: latest
firebase_auth: latest
cloud_firestore: latest
firebase_storage: latest
google_sign_in: latest
flutter_riverpod: latest
riverpod_annotation: latest
go_router: latest
google_generative_ai: latest
intl: latest
uuid: latest
purchases_flutter: latest