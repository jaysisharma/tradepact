class EnvConfig {
  static const revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue:
        'goog_dIvkmkIILUfwGOHMxoqUsZrTHgw', // <-- PASTE REVENUECAT KEY HERE
  );

  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue:
        'AIzaSyDPQj6BqWhicNCKmb616yeExMvgfIEQ7cI', // <-- PASTE GEMINI KEY HERE
  );

  static bool get hasRevenueCatKey => revenueCatApiKey.isNotEmpty;
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
