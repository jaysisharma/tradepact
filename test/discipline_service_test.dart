import 'package:flutter_test/flutter_test.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/discipline_service.dart';

void main() {
  final service = DisciplineService();

  TradeModel makeTrade({
    bool followedPlan = false,
    bool respectedSL = false,
    String mood = 'neutral',
  }) {
    return TradeModel(
      id: 't',
      pair: 'XAUUSD',
      direction: 'BUY',
      entry: 1900,
      sl: 1890,
      tp: 1920,
      exitPrice: 1920,
      result: 'WIN',
      pnl: 200,
      rr: 2,
      lots: 1,
      mood: mood,
      reason: 'setup',
      followedPlan: followedPlan,
      respectedSL: respectedSL,
      session: 'London',
      timestamp: DateTime(2024, 1, 1),
    );
  }

  group('DisciplineService.calculateDisciplineScore', () {
    test('returns 0 for empty list', () {
      expect(service.calculateDisciplineScore([]), 0);
    });

    test('returns 100 for single perfect trade', () {
      expect(
        service.calculateDisciplineScore([
          makeTrade(followedPlan: true, respectedSL: true, mood: 'confident'),
        ]),
        100,
      );
    });

    test('averages scores across multiple trades', () {
      // Trade 1: 100 pts (perfect)
      // Trade 2: 0 pts (revenge, no plan, no SL)
      // Average: 50
      final trades = [
        makeTrade(followedPlan: true, respectedSL: true, mood: 'confident'),
        makeTrade(followedPlan: false, respectedSL: false, mood: 'revenge'),
      ];
      expect(service.calculateDisciplineScore(trades), 50);
    });

    test('rounds fractional averages', () {
      // Trade 1: 100, Trade 2: 30, Trade 3: 30 → avg = 53.33 → rounds to 53
      final trades = [
        makeTrade(followedPlan: true, respectedSL: true, mood: 'confident'),
        makeTrade(followedPlan: false, respectedSL: false, mood: 'neutral'),
        makeTrade(followedPlan: false, respectedSL: false, mood: 'neutral'),
      ];
      expect(service.calculateDisciplineScore(trades), 53);
    });
  });
}
