import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/trade_model.dart';

final disciplineServiceProvider = Provider<DisciplineService>((ref) {
  return DisciplineService();
});

class DisciplineService {
  /// Calculates the average discipline score (0–100) across all trades.
  ///
  /// Per-trade formula (from CLAUDE.md):
  ///   followedPlan   → 40 pts
  ///   no revenge/impulse mood → 30 pts
  ///   respectedSL    → 30 pts
  ///
  /// Overall score = average of all per-trade scores, rounded.
  int calculateDisciplineScore(List<TradeModel> trades) {
    if (trades.isEmpty) return 0;
    final total = trades.fold<int>(0, (acc, t) => acc + t.disciplineScore);
    return (total / trades.length).round();
  }
}
