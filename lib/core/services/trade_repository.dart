import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/trade_model.dart';
import 'package:tradepact/core/models/user_profile_model.dart';
import 'package:tradepact/core/services/auth_service.dart';
import 'package:tradepact/core/services/discipline_service.dart';

final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  return TradeRepository(ref.read(disciplineServiceProvider));
});

final tradesProvider = StreamProvider<List<TradeModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.watch(tradeRepositoryProvider).getTrades(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final userStatsProvider = StreamProvider<UserStatsModel>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(const UserStatsModel());
      return ref.watch(tradeRepositoryProvider).watchStats(user.uid);
    },
    loading: () => Stream.value(const UserStatsModel()),
    error: (_, __) => Stream.value(const UserStatsModel()),
  );
});

/// Sum of PnL for all trades logged today (local timezone).
final todayPnlProvider = Provider<double>((ref) {
  final trades = ref.watch(tradesProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return trades
      .where((t) => !t.timestamp.isBefore(todayStart))
      .fold<double>(0, (acc, t) => acc + t.pnl);
});

class TradeRepository {
  final DisciplineService _disciplineService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TradeRepository(this._disciplineService);

  CollectionReference<Map<String, dynamic>> _tradesRef(String uid) {
    return _db.collection('users').doc(uid).collection('trades');
  }

  DocumentReference<Map<String, dynamic>> _statsRef(String uid) {
    return _db.collection('users').doc(uid).collection('stats').doc('summary');
  }

  Stream<List<TradeModel>> getTrades(String uid) {
    return _tradesRef(uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => TradeModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addTrade(String uid, TradeModel trade) async {
    await _tradesRef(uid).add(trade.toJson());
    await _recalculateStats(uid);
  }

  Future<void> updateTrade(String uid, TradeModel trade) async {
    await _tradesRef(uid).doc(trade.id).update(trade.toJson());
    await _recalculateStats(uid);
  }

  Future<void> deleteTrade(String uid, String tradeId) async {
    await _tradesRef(uid).doc(tradeId).delete();
    await _recalculateStats(uid);
  }

  Stream<UserStatsModel> watchStats(String uid) {
    return _statsRef(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return const UserStatsModel();
      return UserStatsModel.fromJson(snap.data()!);
    });
  }

  Future<void> _recalculateStats(String uid) async {
    final snap = await _tradesRef(uid)
        .orderBy('timestamp', descending: true)
        .get();
    final trades =
        snap.docs.map((d) => TradeModel.fromJson(d.data(), d.id)).toList();

    if (trades.isEmpty) {
      await _statsRef(uid).set(const UserStatsModel().toJson());
      return;
    }

    final wins = trades.where((t) => t.result == 'WIN').length;
    final losses = trades.where((t) => t.result == 'LOSS').length;
    final totalPnl = trades.fold<double>(0, (acc, t) => acc + t.pnl);
    final disciplineScore = _disciplineService.calculateDisciplineScore(trades);
    final streak = _calculateDayStreak(trades);

    final stats = UserStatsModel(
      totalTrades: trades.length,
      wins: wins,
      losses: losses,
      totalPnl: totalPnl,
      currentStreak: streak,
      disciplineScore: disciplineScore,
    );

    await _statsRef(uid).set(stats.toJson());
  }

  /// Counts consecutive days (ending today or yesterday) that have ≥1 trade.
  /// Resets to 0 if the user has not traded today or yesterday.
  ///
  /// Exposed as a static for unit testing (pure function, no Firestore needed).
  @visibleForTesting
  static int calculateDayStreak(List<TradeModel> trades) =>
      _calculateDayStreakStatic(trades);

  int _calculateDayStreak(List<TradeModel> trades) =>
      _calculateDayStreakStatic(trades);

  static int _calculateDayStreakStatic(List<TradeModel> trades) {
    if (trades.isEmpty) return 0;

    // Build the set of unique calendar days that have at least one trade.
    final tradeDays = trades
        .map((t) =>
            DateTime(t.timestamp.year, t.timestamp.month, t.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // descending

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak must be anchored to today or yesterday to still be active.
    if (tradeDays.first != today && tradeDays.first != yesterday) return 0;

    int streak = 0;
    DateTime expected = tradeDays.first;
    for (final day in tradeDays) {
      if (day == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }
}
