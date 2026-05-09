import 'package:flutter_test/flutter_test.dart';
import 'package:tradepact/core/models/trade_model.dart';

void main() {
  // ── Helpers ──────────────────────────────────────────────────────────────

  TradeModel makeTrade({
    String mood = 'neutral',
    bool followedPlan = false,
    bool respectedSL = false,
    double entry = 1900,
    double sl = 1890,
    double tp = 1920,
    double exitPrice = 1920,
    String direction = 'BUY',
    double lots = 1.0,
    String pair = 'XAUUSD',
    String result = 'WIN',
  }) {
    return TradeModel(
      id: 'test',
      pair: pair,
      direction: direction,
      entry: entry,
      sl: sl,
      tp: tp,
      exitPrice: exitPrice,
      result: result,
      pnl: 0,
      rr: 0,
      lots: lots,
      mood: mood,
      reason: 'setup',
      followedPlan: followedPlan,
      respectedSL: respectedSL,
      session: 'London',
      timestamp: DateTime(2024, 1, 1),
    );
  }

  // ── disciplineScore ───────────────────────────────────────────────────────

  group('TradeModel.disciplineScore', () {
    test('returns 0 when no discipline flags set', () {
      expect(
        makeTrade(mood: 'neutral', followedPlan: false, respectedSL: false)
            .disciplineScore,
        30, // neutral mood gives 30 pts
      );
    });

    test('returns 100 for perfect trade', () {
      expect(
        makeTrade(mood: 'confident', followedPlan: true, respectedSL: true)
            .disciplineScore,
        100,
      );
    });

    test('followedPlan contributes 40 pts', () {
      final withPlan =
          makeTrade(followedPlan: true, respectedSL: false, mood: 'revenge');
      final withoutPlan =
          makeTrade(followedPlan: false, respectedSL: false, mood: 'revenge');
      expect(withPlan.disciplineScore - withoutPlan.disciplineScore, 40);
    });

    test('respectedSL contributes 30 pts', () {
      final with_ = makeTrade(respectedSL: true, followedPlan: false, mood: 'revenge');
      final without = makeTrade(respectedSL: false, followedPlan: false, mood: 'revenge');
      expect(with_.disciplineScore - without.disciplineScore, 30);
    });

    test('revenge mood gives 0 mood points', () {
      expect(
        makeTrade(mood: 'revenge', followedPlan: false, respectedSL: false)
            .disciplineScore,
        0,
      );
    });

    test('non-revenge/non-impulse mood gives 30 pts', () {
      for (final mood in ['neutral', 'confident', 'anxious', 'bored']) {
        expect(
          makeTrade(mood: mood, followedPlan: false, respectedSL: false)
              .disciplineScore,
          30,
          reason: 'mood=$mood',
        );
      }
    });
  });

  // ── fromJson / toJson round-trip ──────────────────────────────────────────

  group('TradeModel serialisation', () {
    test('toJson contains all required fields', () {
      final t = makeTrade();
      final json = t.toJson();
      for (final key in [
        'pair', 'direction', 'entry', 'sl', 'tp', 'exitPrice',
        'result', 'pnl', 'rr', 'lots', 'mood', 'reason',
        'followedPlan', 'respectedSL', 'session', 'timestamp',
      ]) {
        expect(json.containsKey(key), isTrue, reason: 'missing key: $key');
      }
    });

    test('fromJson defaults unknown fields gracefully', () {
      final t = TradeModel.fromJson({}, 'id1');
      expect(t.pair, '');
      expect(t.direction, 'BUY');
      expect(t.mood, 'neutral');
      expect(t.result, 'BE');
    });

    test('copyWith preserves unchanged fields', () {
      final original = makeTrade(pair: 'EURUSD', mood: 'confident');
      final copy = original.copyWith(mood: 'revenge');
      expect(copy.pair, 'EURUSD');
      expect(copy.mood, 'revenge');
      expect(copy.followedPlan, original.followedPlan);
    });
  });
}
