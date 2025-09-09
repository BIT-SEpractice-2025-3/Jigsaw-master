// lib/models/match.dart

/// 对战模型，用于实时对战流程
class Match {
  final int id;
  final int challengerId;
  final int opponentId;
  final String difficulty;
  final String imageSource;
  final String status;

  Match({
    required this.id,
    required this.challengerId,
    required this.opponentId,
    required this.difficulty,
    required this.imageSource,
    required this.status,
  });

  /// 从JSON数据创建Match对象的工厂构造函数
  /// 兼容后端在 'match_started' 事件中包装的 'match_details'
  factory Match.fromJson(Map<String, dynamic> json) {
    // 后端在 match_started 事件中，可能会把 match 对象包在 'match_details' key里
    final details = json['match_details'] ?? json;

    return Match(
      id: details['id'],
      challengerId: details['challenger_id'],
      opponentId: details['opponent_id'],
      difficulty: details['difficulty'],
      imageSource: details['image_source'],
      status: details['status'] ?? 'pending',
    );
  }

  /// 将难度字符串转换为用户友好的文本
  String get difficultyText {
    switch (difficulty) {
      case '1':
      case 'easy':
        return '简单';
      case '2':
      case 'medium':
        return '中等';
      case '3':
      case 'hard':
        return '困难';
      case 'master':
        return '大师';
      default:
        return '未知难度';
    }
  }
}

/// 比赛结果模型，用于比赛历史记录
class MatchResult {
  final int id;
  final int winnerId;
  final String challengerUsername; // 需要后端在查询历史记录时JOIN users表
  final String opponentUsername;   // 需要后端在查询历史记录时JOIN users表
  final int challengerTimeMs;
  final int opponentTimeMs;
  final DateTime completedAt;

  MatchResult({
    required this.id,
    required this.winnerId,
    required this.challengerUsername,
    required this.opponentUsername,
    required this.challengerTimeMs,
    required this.opponentTimeMs,
    required this.completedAt,
  });

  /// 从JSON数据创建MatchResult对象的工厂构造函数
  /// 这个通常用于从HTTP API获取比赛历史记录
  factory MatchResult.fromJson(Map<String, dynamic> json) {
    return MatchResult(
      id: json['id'],
      winnerId: json['winner_id'],
      challengerUsername: json['challenger_username'] ?? '玩家1',
      opponentUsername: json['opponent_username'] ?? '玩家2',
      challengerTimeMs: json['challenger_time_ms'] ?? 0,
      opponentTimeMs: json['opponent_time_ms'] ?? 0,
      completedAt: DateTime.parse(json['completed_at']),
    );
  }

  /// 格式化毫秒为 "分:秒.毫秒" 的字符串
  String formatTime(int ms) {
    final duration = Duration(milliseconds: ms);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 100).toString();
    return "$minutes:$seconds.$milliseconds";
  }
}