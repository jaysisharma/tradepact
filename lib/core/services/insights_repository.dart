import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tradepact/core/models/insight_model.dart';
import 'package:tradepact/core/services/auth_service.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository();
});

/// Streams the current week's insight, or null if none has been generated yet.
final currentWeekInsightProvider = StreamProvider<InsightModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref
          .watch(insightsRepositoryProvider)
          .watchCurrentWeekInsight(user.uid);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

class InsightsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _insightsRef(String uid) {
    return _db.collection('users').doc(uid).collection('insights');
  }

  /// Returns the ISO week ID for [date], e.g. "2026-W14".
  static String weekIdFor(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    final y = monday.year.toString();
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Stream<InsightModel?> watchCurrentWeekInsight(String uid) {
    final weekId = weekIdFor(DateTime.now());
    return _insightsRef(uid).doc(weekId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return InsightModel.fromJson(snap.data()!, weekId);
    });
  }

  Future<void> saveInsight(String uid, InsightModel insight) async {
    await _insightsRef(uid).doc(insight.weekId).set(insight.toJson());
  }
}
