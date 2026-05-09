import 'package:cloud_firestore/cloud_firestore.dart';

class InsightModel {
  final String weekId;

  /// Newline-separated bullet points produced by Gemini.
  final String summary;
  final DateTime generatedAt;

  const InsightModel({
    required this.weekId,
    required this.summary,
    required this.generatedAt,
  });

  factory InsightModel.fromJson(Map<String, dynamic> json, String weekId) {
    return InsightModel(
      weekId: weekId,
      summary: json['summary'] as String? ?? '',
      generatedAt:
          (json['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  InsightModel copyWith({
    String? weekId,
    String? summary,
    DateTime? generatedAt,
  }) {
    return InsightModel(
      weekId: weekId ?? this.weekId,
      summary: summary ?? this.summary,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  /// Splits the summary into individual bullet lines, filtering blanks.
  List<String> get bullets =>
      summary.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}
