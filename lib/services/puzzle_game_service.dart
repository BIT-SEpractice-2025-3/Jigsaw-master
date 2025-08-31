//游戏服务
import 'dart:async';
import 'dart:ui' as ui;
import '/models/puzzle_piece.dart';
// 游戏状态枚举
enum GameStatus {
  notStarted,  // 未开始
  inProgress,  // 进行中
  paused,      // 暂停
  completed    // 已完成
}

class PuzzleGameService {
  // 游戏状态
  GameStatus _status = GameStatus.notStarted;
  GameStatus get status => _status;

  // 游戏难度
  int _difficulty = 1;
  int get difficulty => _difficulty;

  // 游戏计时（秒）
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;
  Timer? _timer;

  // 拼图碎片
  List<PuzzlePiece> _availablePieces = []; // 待放置的碎片
  List<PuzzlePiece?> _placedPieces = [];   // 已放置的碎片

  // 获取拼图碎片（只读）
  List<PuzzlePiece> get availablePieces => List.unmodifiable(_availablePieces);
  List<PuzzlePiece?> get placedPieces => List.unmodifiable(_placedPieces);

  // 游戏状态变化流
  final _statusController = StreamController<GameStatus>.broadcast();
  Stream<GameStatus> get statusStream => _statusController.stream;

  // 新增：计时器更新流
  final _timerController = StreamController<int>.broadcast();
  Stream<int> get timerStream => _timerController.stream;

  // 初始化游戏
  Future<void> initGame(List<PuzzlePiece> pieces, int difficulty) async {
    _difficulty = difficulty;
    _availablePieces = List.from(pieces);
    // 修正：根据难度计算正确的网格大小
    final gridSize = difficulty + 2;
    _placedPieces = List.filled(gridSize * gridSize, null);
    _elapsedSeconds = 0;
    _timerController.add(_elapsedSeconds); // 初始化时通知UI
    _status = GameStatus.notStarted;
    _statusController.add(_status);
  }

  // 开始游戏
  void startGame() {
    if (_status == GameStatus.notStarted || _status == GameStatus.paused) {
      _status = GameStatus.inProgress;
      _statusController.add(_status);
      _startTimer();
    }
  }

  // 暂停游戏
  void pauseGame() {
    if (_status == GameStatus.inProgress) {
      _status = GameStatus.paused;
      _statusController.add(_status);
      _stopTimer();
    }
  }

  // 简化放置拼图的逻辑，不再需要位置参数
  bool placePiece(int pieceIndex, int targetPosition) {
    // 验证参数
    if (_status != GameStatus.inProgress) return false;
    if (targetPosition < 0 || targetPosition >= _placedPieces.length) return false;
    if (_placedPieces[targetPosition] != null) return false;
    if (pieceIndex < 0 || pieceIndex >= _availablePieces.length) return false;

    // 获取并移除待放置的拼图块
    final piece = _availablePieces[pieceIndex];
    _availablePieces.removeAt(pieceIndex);

    // 放置到目标位置
    _placedPieces[targetPosition] = piece;

    // 检查游戏是否完成
    _checkGameCompletion();

    return true;
  }

  // 移除已放置的拼图碎片
  PuzzlePiece? removePiece(int position) {
    if (_status != GameStatus.inProgress) return null;

    // TODO: 实现拼图移除逻辑
    return null;
  }

  // 检查游戏是否完成
  void _checkGameCompletion() {
    // 检查是否所有碎片都正确放置
    bool allPiecesPlaced = true;
    for (var piece in _placedPieces) {
      if (piece == null) {
        allPiecesPlaced = false;
        break;
      }
    }

    if (allPiecesPlaced) {
      _status = GameStatus.completed;
      _statusController.add(_status);
      _stopTimer();
    }
  }

  // 开始计时
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _timerController.add(_elapsedSeconds); // 每秒通知UI
    });
  }

  // 停止计时
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // 重置游戏
  void resetGame() {
    _stopTimer();
    _elapsedSeconds = 0;
    _timerController.add(_elapsedSeconds); // 重置时通知UI
    _placedPieces = List.filled((_difficulty + 2) * (_difficulty + 2), null);
    _status = GameStatus.notStarted;
    _statusController.add(_status);
  }

  // 获取游戏分数
  int calculateScore() {
    if (_status != GameStatus.completed) return 0;

    // 分数计算逻辑：基于时间、难度和完成度
    final int baseScore = 1000; // 基础分数
    final int timePenalty = _elapsedSeconds * 10; // 时间惩罚（每秒扣10分）
    final int difficultyBonus = _difficulty * 200; // 难度奖励

    // 计算最终分数（确保不为负数）
    int finalScore = baseScore - timePenalty + difficultyBonus;

    // 确保分数不为负
    if (finalScore < 0) {
      finalScore = 0;
    }

    // 根据完成度调整分数（所有碎片都正确放置，所以是100%）
    final double completionRate = 1.0; // 100%完成
    finalScore = (finalScore * completionRate).round();

    return finalScore;
  }

  // 释放资源
  void dispose() {
    _stopTimer();
    _statusController.close();
    _timerController.close(); // 关闭计时器流
  }
}
