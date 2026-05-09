import 'package:flutter_test/flutter_test.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/services/trade_repository.dart';

TradeModel _tradeOn(DateTime date) => TradeModel(
      id: date.toIso8601String(),
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
      mood: 'neutral',
      reason: 'setup',
      followedPlan: true,
      respectedSL: true,
      session: 'London',
      timestamp: date,
    );

void main() {
  final today = DateTime.now();
  DateTime d(int daysAgo) =>
      DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: daysAgo));

  group('_calculateDayStreak', () {
    test('returns 0 for empty list', () {
      expect(TradeRepository.calculateDayStreak([]), 0);
    });

    test('returns 0 if last trade was 2+ days ago', () {
      final trades = [_tradeOn(d(2)), _tradeOn(d(3))];
      expect(TradeRepository.calculateDayStreak(trades), 0);
    });

    test('returns 1 if only today has a trade', () {
      expect(TradeRepository.calculateDayStreak([_tradeOn(d(0))]), 1);
    });

    test('returns 1 if only yesterday has a trade', () {
      expect(TradeRepository.calculateDayStreak([_tradeOn(d(1))]), 1);
    });

    test('counts consecutive days correctly', () {
      final trades = [
        _tradeOn(d(0)),
        _tradeOn(d(1)),
        _tradeOn(d(2)),
        _tradeOn(d(3)),
      ];
      expect(TradeRepository.calculateDayStreak(trades), 4);
    });

    test('breaks on gap', () {
      final trades = [
        _tradeOn(d(0)),
        _tradeOn(d(1)),
        // gap: day 2 missing
        _tradeOn(d(3)),
        _tradeOn(d(4)),
      ];
      expect(TradeRepository.calculateDayStreak(trades), 2);
    });

    test('multiple trades on same day count as one streak day', () {
      final trades = [
        _tradeOn(d(0)),
        _tradeOn(d(0)), // duplicate day
        _tradeOn(d(1)),
      ];
      expect(TradeRepository.calculateDayStreak(trades), 2);
    });
  });
}
