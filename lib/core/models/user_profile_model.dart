class UserProfileModel {
  final String uid;
  final String name;
  final String email;
  final String propFirm;
  final double accountSize;
  final double dailyLossLimit;
  final double maxDrawdown;

  const UserProfileModel({
    required this.uid,
    required this.name,
    required this.email,
    this.propFirm = '',
    this.accountSize = 0.0,
    this.dailyLossLimit = 0.0,
    this.maxDrawdown = 0.0,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserProfileModel(
      uid: uid,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      propFirm: json['propFirm'] as String? ?? '',
      accountSize: (json['accountSize'] as num?)?.toDouble() ?? 0.0,
      dailyLossLimit: (json['dailyLossLimit'] as num?)?.toDouble() ?? 0.0,
      maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'propFirm': propFirm,
      'accountSize': accountSize,
      'dailyLossLimit': dailyLossLimit,
      'maxDrawdown': maxDrawdown,
    };
  }

  UserProfileModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? propFirm,
    double? accountSize,
    double? dailyLossLimit,
    double? maxDrawdown,
  }) {
    return UserProfileModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      propFirm: propFirm ?? this.propFirm,
      accountSize: accountSize ?? this.accountSize,
      dailyLossLimit: dailyLossLimit ?? this.dailyLossLimit,
      maxDrawdown: maxDrawdown ?? this.maxDrawdown,
    );
  }
}

class UserStatsModel {
  final int totalTrades;
  final int wins;
  final int losses;
  final double totalPnl;
  final int currentStreak;
  final int disciplineScore;

  const UserStatsModel({
    this.totalTrades = 0,
    this.wins = 0,
    this.losses = 0,
    this.totalPnl = 0.0,
    this.currentStreak = 0,
    this.disciplineScore = 0,
  });

  double get winRate => totalTrades == 0 ? 0.0 : (wins / totalTrades) * 100;

  factory UserStatsModel.fromJson(Map<String, dynamic> json) {
    return UserStatsModel(
      totalTrades: json['totalTrades'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      totalPnl: (json['totalPnl'] as num?)?.toDouble() ?? 0.0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      disciplineScore: json['disciplineScore'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalTrades': totalTrades,
      'wins': wins,
      'losses': losses,
      'totalPnl': totalPnl,
      'currentStreak': currentStreak,
      'disciplineScore': disciplineScore,
    };
  }

  UserStatsModel copyWith({
    int? totalTrades,
    int? wins,
    int? losses,
    double? totalPnl,
    int? currentStreak,
    int? disciplineScore,
  }) {
    return UserStatsModel(
      totalTrades: totalTrades ?? this.totalTrades,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      totalPnl: totalPnl ?? this.totalPnl,
      currentStreak: currentStreak ?? this.currentStreak,
      disciplineScore: disciplineScore ?? this.disciplineScore,
    );
  }
}
