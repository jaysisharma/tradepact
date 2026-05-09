import 'package:cloud_firestore/cloud_firestore.dart';

class TradeModel {
  final String id;
  final String pair;
  final String direction;
  final double entry;
  final double sl;
  final double tp;
  final double exitPrice;
  final String result;
  final double pnl;
  final double rr;
  final double lots;
  final String mood;
  final String reason;
  final bool followedPlan;
  final bool respectedSL;
  final String session;
  final String screenshotUrl;
  final String notes;
  final DateTime timestamp;

  const TradeModel({
    required this.id,
    required this.pair,
    required this.direction,
    required this.entry,
    required this.sl,
    required this.tp,
    required this.exitPrice,
    required this.result,
    required this.pnl,
    required this.rr,
    required this.lots,
    required this.mood,
    required this.reason,
    required this.followedPlan,
    required this.respectedSL,
    required this.session,
    this.screenshotUrl = '',
    this.notes = '',
    required this.timestamp,
  });

  int get disciplineScore {
    int score = 0;
    if (followedPlan) score += 40;
    if (mood != 'revenge' && mood != 'impulse') score += 30;
    if (respectedSL) score += 30;
    return score;
  }

  factory TradeModel.fromJson(Map<String, dynamic> json, String id) {
    return TradeModel(
      id: id,
      pair: json['pair'] as String? ?? '',
      direction: json['direction'] as String? ?? 'BUY',
      entry: (json['entry'] as num?)?.toDouble() ?? 0.0,
      sl: (json['sl'] as num?)?.toDouble() ?? 0.0,
      tp: (json['tp'] as num?)?.toDouble() ?? 0.0,
      exitPrice: (json['exitPrice'] as num?)?.toDouble() ?? 0.0,
      result: json['result'] as String? ?? 'BE',
      pnl: (json['pnl'] as num?)?.toDouble() ?? 0.0,
      rr: (json['rr'] as num?)?.toDouble() ?? 0.0,
      lots: (json['lots'] as num?)?.toDouble() ?? 0.0,
      mood: json['mood'] as String? ?? 'neutral',
      reason: json['reason'] as String? ?? 'other',
      followedPlan: json['followedPlan'] as bool? ?? false,
      respectedSL: json['respectedSL'] as bool? ?? false,
      session: json['session'] as String? ?? 'Other',
      screenshotUrl: json['screenshotUrl'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pair': pair,
      'direction': direction,
      'entry': entry,
      'sl': sl,
      'tp': tp,
      'exitPrice': exitPrice,
      'result': result,
      'pnl': pnl,
      'rr': rr,
      'lots': lots,
      'mood': mood,
      'reason': reason,
      'followedPlan': followedPlan,
      'respectedSL': respectedSL,
      'session': session,
      'screenshotUrl': screenshotUrl,
      'notes': notes,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  TradeModel copyWith({
    String? id,
    String? pair,
    String? direction,
    double? entry,
    double? sl,
    double? tp,
    double? exitPrice,
    String? result,
    double? pnl,
    double? rr,
    double? lots,
    String? mood,
    String? reason,
    bool? followedPlan,
    bool? respectedSL,
    String? session,
    String? screenshotUrl,
    String? notes,
    DateTime? timestamp,
  }) {
    return TradeModel(
      id: id ?? this.id,
      pair: pair ?? this.pair,
      direction: direction ?? this.direction,
      entry: entry ?? this.entry,
      sl: sl ?? this.sl,
      tp: tp ?? this.tp,
      exitPrice: exitPrice ?? this.exitPrice,
      result: result ?? this.result,
      pnl: pnl ?? this.pnl,
      rr: rr ?? this.rr,
      lots: lots ?? this.lots,
      mood: mood ?? this.mood,
      reason: reason ?? this.reason,
      followedPlan: followedPlan ?? this.followedPlan,
      respectedSL: respectedSL ?? this.respectedSL,
      session: session ?? this.session,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
