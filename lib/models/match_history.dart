// lib/models/match_history.dart

class MatchHistory {
  final int id;
  final int opponentId;
  final String opponentUsername;
  final String result; // '胜利' 或 '失败'
  final String difficulty;
  final DateTime completedAt;

  MatchHistory({
    required this.id,
    required this.opponentId,
    required this.opponentUsername,
    required this.result,
    required this.difficulty,
    required this.completedAt,
  });

  factory MatchHistory.fromJson(Map<String, dynamic> json) {
    return MatchHistory(
      id: json['id'],
      opponentId: json['opponent_id'],
      opponentUsername: json['opponent_username'],
      result: json['result'],
      difficulty: json['difficulty'],
      completedAt: DateTime.parse(json['completed_at']),
    );
  }
}