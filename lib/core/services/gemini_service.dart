import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:tradepact/core/config/env_config.dart';
import 'package:tradepact/core/models/trade_model.dart';

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
class GeminiService {
  late final GenerativeModel? _model;
  
  GeminiService() {
    if (EnvConfig.hasGeminiKey) {
      _model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: EnvConfig.geminiApiKey,
      );
    } else {
      _model = null;
    }
  }

  /// Sends a chart screenshot to Gemini and returns a map of parsed trade fields.
  /// Returns null if parsing fails or the API key is not configured.
  ///
  /// Expected response JSON:
  /// {"pair": "", "direction": "BUY|SELL", "entry": 0.0, "sl": 0.0, "tp": 0.0}
  Future<Map<String, dynamic>?> parseChartScreenshot(
      Uint8List imageBytes) async {
    if (_model == null) return null;

    try {
      final prompt = TextPart(
        'Analyze this trading chart screenshot and extract the visible trade setup.\n'
        'Return ONLY valid JSON — no explanation, no markdown code fences:\n'
        '{"pair":"<instrument>","direction":"BUY or SELL","entry":0.0,"sl":0.0,"tp":0.0}\n'
        'Use 0.0 for any value you cannot determine. '
        'Use an empty string "" for pair/direction if unknown.',
      );
      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final raw = response.text?.trim() ?? '';
      debugPrint('[GeminiService] Raw response: $raw');
      // Strip accidental markdown fences.
      final jsonStr = raw
          .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'```\s*', multiLine: true), '')
          .trim();

      debugPrint('[GeminiService] Cleaned JSON: $jsonStr');

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      debugPrint('[GeminiService] Parsed Map: $map');
      return map;
    } catch (e) {
      debugPrint('[GeminiService] Error parsing response: $e');
      return null;
    }
  }

  /// Sends the last 7 days of trades to Gemini and returns a formatted insight
  /// string with exactly 3 bullet points.
  /// Returns null if the API key is not configured or the request fails.
  Future<String?> generateWeeklyInsight(List<TradeModel> trades) async {
    if (_model == null) return null;
    if (trades.isEmpty) return null;

    try {
      final tradeSummaries = trades.map((t) {
        return '${t.pair} ${t.direction} | ${t.result} | PnL: \$${t.pnl.toStringAsFixed(2)} '
            '| RR: 1:${t.rr.toStringAsFixed(1)} | Mood: ${t.mood} '
            '| Followed plan: ${t.followedPlan} | Respected SL: ${t.respectedSL}';
      }).join('\n');

      final prompt = '''
You are a professional trading coach analyzing a prop trader's last 7 days of trades.

Trades:
$tradeSummaries

Give exactly 3 bullet points. Each bullet must be max 2 lines.
Focus on: patterns you see, the biggest weakness, one specific improvement for next week.
Start each bullet with "• " on its own line.
No introduction or closing text — just the 3 bullets.
''';

      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (_) {
      return null;
    }
  }
}
